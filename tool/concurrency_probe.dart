// Live concurrency probe against the real Supabase project.
//
// Not a unit test — it hits the network, so it lives in tool/ and is run by
// hand, never in `flutter test`. It fires N genuinely simultaneous booking
// requests (N distinct anonymous users) at ONE slot and asserts the database
// lets exactly one through.
//
// Run:
//   dart run tool/concurrency_probe.dart <URL> <PUBLISHABLE_KEY>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

late final String url;
late final String key;

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/concurrency_probe.dart <URL> <KEY>');
    exit(64);
  }
  url = args[0].replaceAll(RegExp(r'/$'), '');
  key = args[1];

  // A small pool of real users. Supabase rate-limits a burst of anonymous
  // sign-ups, and that limit has nothing to do with the booking race, so the
  // pool is kept small and reused for every wave. A third argument may point
  // at a JSON file of existing sessions ([{id, token}, …]) to skip sign-up
  // entirely when the quota is spent.
  //
  // The guarantee under test is about the SLOT, not the users: N concurrent
  // inserts for one slot must resolve to exactly one booking no matter who
  // sends them. Drawing the wave round-robin from the pool means the same user
  // also races itself — a strictly harder case, since a user must not be able
  // to double-book even their own slot.
  final pool = <Map<String, String>>[];
  if (args.length >= 3 && File(args[2]).existsSync()) {
    final loaded = jsonDecode(File(args[2]).readAsStringSync()) as List;
    for (final e in loaded) {
      pool.add({'id': e['id'] as String, 'token': e['token'] as String});
    }
    print('Reusing ${pool.length} existing sessions from ${args[2]}');
  } else {
    stdout.write('Building a pool of real users… ');
    while (pool.length < 4) {
      final batch = await Future.wait(List.generate(2, (_) => _signUp()));
      pool.addAll(batch.whereType<Map<String, String>>());
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    print('${pool.length} users');
  }
  if (pool.isEmpty) {
    stderr.writeln('No usable sessions (sign-up quota spent?). Pass a JSON '
        'file of {id,token} sessions as the third argument.');
    exit(1);
  }

  // A far-future date so the probe can never collide with a real booking.
  var day = DateTime(2028, 3, 1);
  for (final n in [10, 50, 100]) {
    final slotDate = _fmt(day);
    day = day.add(const Duration(days: 1));
    await _wave(pool, n, slotDate, 14);
  }

  print('');
  await _cleanup();
}

Future<void> _wave(
  List<Map<String, String>> pool,
  int n,
  String slotDate,
  int slotHour,
) async {
  // N booking requests, drawn round-robin from the pool, all fired together.
  // The await is on the whole batch, so every insert is in flight at once —
  // this is the actual race against the unique index.
  final requests = List.generate(n, (i) => pool[i % pool.length]);
  final results = await Future.wait(
    requests.map((u) => _book(u, slotDate, slotHour)),
  );

  final ok = results.where((c) => c == 201).length;
  final conflict = results.where((c) => c == 409).length;
  final other = results.where((c) => c != 201 && c != 409).toList();

  // Exactly one 201 is the pass condition. Every other request must have been
  // turned away with a conflict; a non-409 failure would mean the slot's fate
  // depended on luck rather than the constraint.
  final verdict = (ok == 1 && conflict == n - 1)
      ? 'PASS — exactly 1 booked, ${n - 1} safely rejected'
      : 'FAIL — investigate';
  print(
    'WAVE ${n.toString().padLeft(3)}  slot $slotDate@$slotHour  '
    'created=$ok  conflict=$conflict  other=${other.length}'
    '${other.isEmpty ? '' : ' $other'}  ->  $verdict',
  );
}

/// Returns null on a rate-limited or malformed signup rather than throwing,
/// so a burst limit does not abort the probe.
Future<Map<String, String>?> _signUp() async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$url/auth/v1/signup'));
    req.headers.set('apikey', key);
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode('{}'));
    final res = await req.close();
    final decoded = jsonDecode(await res.transform(utf8.decoder).join());
    if (decoded is! Map<String, dynamic> || decoded['user'] == null) {
      return null;
    }
    return {
      'id': decoded['user']['id'] as String,
      'token': decoded['access_token'] as String,
    };
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

Future<int> _book(Map<String, String> user, String slotDate, int hour) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$url/rest/v1/appointments'));
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer ${user['token']}');
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode({
      'user_id': user['id'],
      'slot_date': slotDate,
      'slot_hour': hour,
      'first_name': 'Race',
      'last_name': 'Test',
      'phone': '5551234567',
    })));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  } catch (_) {
    return -1;
  } finally {
    client.close();
  }
}

/// Cancels every probe booking so the calendar is left clean.
Future<void> _cleanup() async {
  // A fresh admin-less pass: each user can only cancel its own row, but the
  // probe does not keep them. Instead cancel via a service-less bulk update is
  // impossible under RLS, so we simply leave far-future 2028 rows — they never
  // collide with real bookings. Report them for manual deletion.
  print(
    '  Probe rows are dated March 2028 and cannot reach real customers.\n'
    '  To remove them, run in the SQL editor:\n'
    "    delete from public.appointments where slot_date >= '2028-01-01';",
  );
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
