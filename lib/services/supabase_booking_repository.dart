import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment.dart';
import '../models/profile.dart';
import '../models/slot.dart';
import 'booking_exception.dart';
import 'booking_repository.dart';

/// Talks to Supabase.
///
/// Every call funnels through [_guard], which turns Postgres and transport
/// errors into the small set of outcomes the UI knows how to explain.
class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._client);

  final SupabaseClient _client;

  /// Unique violation. Raised by `appointments_one_confirmed_per_slot` when a
  /// second person tries to take a slot that is already booked.
  static const String _uniqueViolation = '23505';

  /// Raised by the `appointments_reject_past` trigger, and by nothing else.
  ///
  /// A user-defined SQLSTATE rather than the generic check violation below: the
  /// table's own CHECK constraints (phone, name length, slot_hour, service_id)
  /// raise 23514 too, so matching on that would report any of them to the
  /// customer as "that slot has already started".
  static const String _slotInThePast = 'MN001';

  /// Check violation. One of the column CHECK constraints rejected the row —
  /// which means the client let through something it should have caught, so it
  /// is a bug to surface rather than an outcome to explain.
  static const String _checkViolation = '23514';

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    // Deliberately NOT called at launch. Opening the app must not write
    // anything to the database; an identity is created at the moment the
    // customer commits to something, and only then.
    // Anonymous sign-in gives the device a durable user id without asking
    // anyone to register. It can later be upgraded to a phone or email
    // identity, and the existing bookings come along with it.
    await _guard(() => _client.auth.signInAnonymously());
  }

  @override
  Future<List<Appointment>> fetchMyAppointments() async {
    // No session means this device has never booked, so it has no bookings —
    // an empty list rather than an error, and no round trip to find that out.
    if (currentUserId == null) return const <Appointment>[];

    final userId = _requireUserId();

    final rows = await _guard(
      () => _client
          .from('appointments')
          .select()
          .eq('user_id', userId)
          .order('slot_date')
          .order('slot_hour'),
    );

    return rows
        .cast<Map<String, dynamic>>()
        .map(Appointment.fromRow)
        .toList(growable: false);
  }

  @override
  Future<Set<Slot>> fetchBookedSlots(DateTime from, DateTime to) async {
    // A security-definer function, not a table read: RLS keeps other people's
    // rows invisible, and this returns slot keys only.
    final rows = await _guard(
      () => _client.rpc(
        'booked_slots',
        params: {
          'from_date': Slot(from, 0).dateKey,
          'to_date': Slot(to, 0).dateKey,
        },
      ),
    );

    if (rows is! List) return <Slot>{};

    return rows
        .cast<Map<String, dynamic>>()
        .map(
          (row) => Slot(
            Slot.parseDate(row['slot_date'] as String),
            (row['slot_hour'] as num).toInt(),
          ),
        )
        .toSet();
  }

  @override
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    required String lastName,
    required String phone,
    String? serviceId,
  }) async {
    // The moment a guest becomes a user: an anonymous identity is created here,
    // on a deliberate action, rather than at launch. A device that only browsed
    // leaves no trace in the database.
    await ensureSignedIn();
    final userId = _requireUserId();

    final draft = Appointment(
      id: '',
      userId: userId,
      slot: slot,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      serviceId: serviceId,
    );

    // No "is it free?" query first — that would leave a window between the
    // check and the insert. The insert simply attempts it, and the unique
    // index decides. Losing that race is a normal outcome, not an error.
    final row = await _guard(
      () => _client
          .from('appointments')
          .insert(draft.toInsert())
          .select()
          .single(),
    );

    return Appointment.fromRow(row);
  }

  @override
  Future<void> cancel(String appointmentId) async {
    final userId = _requireUserId();

    await _guard(
      () => _client
          .from('appointments')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', appointmentId)
          .eq('user_id', userId),
    );
  }

  @override
  Future<Profile?> fetchProfile() async {
    // Same as above: no identity yet, so no saved details yet.
    if (currentUserId == null) return null;

    final userId = _requireUserId();

    final row = await _guard(
      () => _client.from('profiles').select().eq('id', userId).maybeSingle(),
    );

    return row == null ? null : Profile.fromRow(row);
  }

  @override
  Future<Profile> saveProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    // Belt and braces. Today this is only ever reached from book(), which has
    // already signed in, and ensureSignedIn() is idempotent — but a profile
    // write needs an identity, and that should not depend on the caller.
    await ensureSignedIn();
    final userId = _requireUserId();

    final profile = Profile(
      id: userId,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    final row = await _guard(
      () => _client
          .from('profiles')
          .upsert(profile.toUpsert())
          .select()
          .single(),
    );

    return Profile.fromRow(row);
  }

  // --- Admin / employee ----------------------------------------------------

  @override
  Future<void> adminSignIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException {
      // Wrong email or password — surface it as such, not as a generic error.
      throw const InvalidAdminCredentialsException();
    } on SocketException {
      throw const BookingOfflineException();
    } on TimeoutException {
      throw const BookingOfflineException();
    }

    // Authenticating is not authorization. Confirm staff membership against the
    // database — the admins RLS policy returns the row only if this user is one
    // — and if not, drop the session again so a non-staff login leaves nothing.
    if (!await isCurrentUserAdmin()) {
      await adminSignOut();
      throw const NotAnAdminException();
    }
  }

  @override
  Future<bool> isCurrentUserAdmin() async {
    final id = currentUserId;
    if (id == null) return false;

    final row = await _guard(
      () => _client.from('admins').select('id').eq('id', id).maybeSingle(),
    );
    return row != null;
  }

  @override
  Future<List<Appointment>> fetchAppointmentsInRange(
    DateTime from,
    DateTime to,
  ) async {
    // One date-range query for the whole visible month; the admin calendar
    // derives both the per-day markers and the selected-day list from this
    // single result, so paging a month is one round trip, never one per day.
    // The admin select-all policy is what makes it return every customer's
    // rows. Cancelled bookings are excluded so a freed day loses its marker.
    final rows = await _guard(
      () => _client
          .from('appointments')
          .select()
          .eq('status', 'confirmed')
          .gte('slot_date', Slot(from, 0).dateKey)
          .lte('slot_date', Slot(to, 0).dateKey)
          .order('slot_date')
          .order('slot_hour'),
    );

    return rows
        .cast<Map<String, dynamic>>()
        .map(Appointment.fromRow)
        .toList(growable: false);
  }

  @override
  Future<void> adminCancel(String appointmentId) async {
    // No user_id filter: the admin update policy authorises cancelling any
    // customer's booking. Cancelling frees the slot via the existing partial
    // unique index — no separate mechanism.
    await _guard(
      () => _client
          .from('appointments')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', appointmentId),
    );
  }

  @override
  Future<void> adminSignOut() => _client.auth.signOut();

  String _requireUserId() {
    final id = currentUserId;
    if (id == null) {
      throw const BookingFailedException('No Supabase session.');
    }
    return id;
  }

  /// Runs [action], translating backend failures into [BookingException]s.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      final translated = translateError(error);
      if (translated == null) rethrow;
      throw translated;
    }
  }

  /// Maps a backend failure to the outcome the UI knows how to explain.
  ///
  /// Kept as a pure function, separate from [_guard], so it can be tested
  /// without a Supabase client. It is worth testing on its own: it decides
  /// which sentence the customer reads, and it matches on codes that are
  /// defined in the migrations rather than here — so if the two ever drift
  /// apart, this is the only place in the app that would notice.
  ///
  /// Returns null for anything that is not a failure this app can explain;
  /// [_guard] lets those propagate untouched rather than guessing at them.
  @visibleForTesting
  static BookingException? translateError(Object error) => switch (error) {
    PostgrestException() => _translatePostgrest(error),
    AuthException() => _translateAuth(error),
    SocketException() => const BookingOfflineException(),
    TimeoutException() => const BookingOfflineException(),
    _ => null,
  };

  static BookingException _translatePostgrest(PostgrestException error) =>
      switch (error.code) {
        _uniqueViolation => const SlotTakenException(),
        _slotInThePast => const SlotInThePastException(),
        _checkViolation => BookingFailedException(
          'A value the app should have validated was rejected by the '
          'database: ${error.message}',
        ),
        _ => BookingFailedException('${error.code}: ${error.message}'),
      };

  static BookingException _translateAuth(AuthException error) {
    // Off by default in a new project, so worth naming precisely.
    if (error.code == 'anonymous_provider_disabled' ||
        error.message.toLowerCase().contains(
          'anonymous sign-ins are disabled',
        )) {
      return const AnonymousSignInDisabledException();
    }
    return BookingFailedException('auth: ${error.message}');
  }
}
