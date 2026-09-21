import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment.dart';
import '../models/customer.dart';
import '../models/salon_closure.dart';
import '../models/salon_service.dart';
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

  /// Unique violation. Raised by `appointments_one_active_per_slot` when a
  /// second person tries to take a slot that is already booked.
  static const String _uniqueViolation = '23505';

  // The salon's own rules, each with its own SQLSTATE so the customer can be
  // told which one they hit rather than "something went wrong". Defined in
  // `supabase/migrations/20260921120000_schema.sql`; the audit script checks
  // that each function still raises its code.
  static const String _slotInThePast = 'MN001';
  static const String _bookingWindow = 'MN002';
  static const String _salonClosed = 'MN003';
  static const String _cancelTooLate = 'MN004';
  static const String _nameMismatch = 'MN005';

  /// The client asked for something that is not there. A bug in the app rather
  /// than a rule the customer broke, so it stays generic on purpose.
  static const String _notFound = 'MN006';

  /// Check violation. One of the column CHECK constraints rejected the row —
  /// which means the client let through something it should have caught.
  static const String _checkViolation = '23514';

  /// Everything needed to render a booking. Line items come along; their
  /// catalogue entries do not, because the catalogue is fifteen rows the app
  /// already holds and joining it per booking would be a round trip for
  /// nothing.
  static const String _appointmentColumns =
      '*, appointment_services(service_id, kind, amount)';

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    // Deliberately NOT called at launch. Opening the app must not write
    // anything to the database; an identity is created at the moment the
    // customer commits to something, and only then.
    await _guard(() => _client.auth.signInAnonymously());
  }

  // --- the person ----------------------------------------------------------

  @override
  Future<Customer?> currentCustomer() async {
    if (currentUserId == null) return null;

    // RLS narrows this to the one customer this device is linked to, so there
    // is no filter to write here — and nothing else is reachable.
    final row = await _guard(
      () => _client.from('customers').select().maybeSingle(),
    );

    return row == null ? null : Customer.fromRow(row);
  }

  @override
  Future<Customer> claimCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    await ensureSignedIn();

    await _guard(
      () => _client.rpc(
        'claim_customer',
        params: {
          'p_first_name': firstName.trim(),
          'p_last_name': _blankToNull(lastName),
          'p_phone': phone,
        },
      ),
    );

    final customer = await currentCustomer();
    if (customer == null) {
      throw const BookingFailedException('Claimed a customer but cannot read it back.');
    }
    return customer;
  }

  @override
  Future<Customer> updateCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    // Editing contact details needs an identity, the same way booking does.
    await ensureSignedIn();

    final existing = await currentCustomer();
    if (existing == null) {
      // Nothing to update yet — this device has never booked, so "saving a
      // profile" is really creating the person.
      return claimCustomer(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
    }

    final row = await _guard(
      () => _client
          .from('customers')
          .update({
            'first_name': firstName.trim(),
            'last_name': _blankToNull(lastName),
            'phone': phone,
          })
          .eq('id', existing.id)
          .select()
          .single(),
    );

    return Customer.fromRow(row);
  }

  // --- browsing ------------------------------------------------------------

  @override
  Future<Set<Slot>> fetchBookedSlots(DateTime from, DateTime to) async {
    // A security-definer function, not a table read: it returns slot keys
    // only, and works without a session so the grid loads for a visitor who
    // has not identified themselves.
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
  Future<Set<DateTime>> fetchClosedDays(DateTime from, DateTime to) async {
    final rows = await _guard(
      () => _client.rpc(
        'closed_days',
        params: {
          'from_date': Slot(from, 0).dateKey,
          'to_date': Slot(to, 0).dateKey,
        },
      ),
    );

    if (rows is! List) return <DateTime>{};

    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => Slot.parseDate(row['day'] as String))
        .toSet();
  }

  @override
  Future<List<SalonService>> fetchTreatments() async {
    final rows = await _guard(
      () => _client
          .from('services')
          .select()
          .eq('kind', 'main')
          .order('sort_order'),
    );

    return rows
        .cast<Map<String, dynamic>>()
        .map(SalonService.fromRow)
        .toList(growable: false);
  }

  // --- this device's bookings ---------------------------------------------

  @override
  Future<List<Appointment>> fetchMyAppointments() async {
    // No session means this device has never booked, so it has no bookings —
    // an empty list rather than an error, and no round trip to find that out.
    if (currentUserId == null) return const <Appointment>[];

    // No filter here either: the select policy already limits this to the
    // linked customer, and to future bookings unless this device made them.
    final rows = await _guard(
      () => _client
          .from('appointments')
          .select(_appointmentColumns)
          .order('slot_date')
          .order('slot_hour'),
    );

    return rows
        .cast<Map<String, dynamic>>()
        .map(Appointment.fromRow)
        .toList(growable: false);
  }

  @override
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    String? lastName,
    required String phone,
    String? serviceId,
  }) async {
    // The moment a visitor becomes a customer: the identity is created here,
    // on a deliberate action, rather than at launch. A device that only
    // browsed leaves no trace in the database.
    await ensureSignedIn();

    // One call: claim the person, insert the booking, record the treatment.
    // There is no "is it free?" query first — that would leave a window
    // between the check and the insert. The unique index decides, and losing
    // that race is a normal outcome, not an error.
    final row = await _guard(
      () => _client.rpc(
        'book_appointment',
        params: {
          'p_first_name': firstName.trim(),
          'p_last_name': _blankToNull(lastName),
          'p_phone': phone,
          'p_slot_date': slot.dateKey,
          'p_slot_hour': slot.hour,
          'p_service_id': serviceId,
        },
      ),
    );

    return Appointment.fromRow(_single(row));
  }

  @override
  Future<Appointment> reschedule(String appointmentId, Slot slot) async {
    final row = await _guard(
      () => _client
          .from('appointments')
          .update({'slot_date': slot.dateKey, 'slot_hour': slot.hour})
          .eq('id', appointmentId)
          .select(_appointmentColumns)
          .single(),
    );

    return Appointment.fromRow(row);
  }

  @override
  Future<void> setTreatment(String appointmentId, String? serviceId) async {
    await _guard(
      () => _client.rpc(
        'set_appointment_service',
        params: {
          'p_appointment_id': appointmentId,
          'p_service_id': serviceId,
        },
      ),
    );
  }

  @override
  Future<void> cancel(String appointmentId) async {
    await _guard(
      () => _client
          .from('appointments')
          .update({
            'status': AppointmentStatus.cancelled.wireName,
            'cancelled_by': 'customer',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', appointmentId),
    );
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

    // Authenticating is not authorization. Confirm staff membership against
    // the database, and if it is not there, drop the session again so a
    // non-staff login leaves nothing behind.
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
    // single result. Cancelled bookings are excluded so a freed day loses its
    // marker; no-shows stay, because the salon still wants to see them.
    final rows = await _guard(
      () => _client
          .from('appointments')
          .select(_appointmentColumns)
          .neq('status', AppointmentStatus.cancelled.wireName)
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
  Future<Appointment> adminBook({
    required Slot slot,
    required String firstName,
    String? lastName,
    required String phone,
    String? serviceId,
  }) async {
    // Staff reach the tables directly, so booking for somebody else is a
    // lookup, an insert and — if they chose a treatment — one line item. The
    // triggers still run; only the window and closed-day rules stand aside,
    // and they do that by reading the flag the database stamps.
    final customerId = await _findOrCreateCustomer(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    final appointment = await _guard(
      () => _client
          .from('appointments')
          .insert({
            'customer_id': customerId,
            'slot_date': slot.dateKey,
            'slot_hour': slot.hour,
            'first_name': firstName.trim(),
            'last_name': _blankToNull(lastName),
            'phone': phone,
          })
          .select(_appointmentColumns)
          .single(),
    );

    if (serviceId != null) {
      await setTreatment(appointment['id'] as String, serviceId);
      return Appointment.fromRow(appointment).copyWith(
        services: await _lineItemsFor(appointment['id'] as String),
      );
    }

    return Appointment.fromRow(appointment);
  }

  @override
  Future<void> adminSetStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    final cancelling = status == AppointmentStatus.cancelled;

    await _guard(
      () => _client
          .from('appointments')
          .update({
            'status': status.wireName,
            'cancelled_by': cancelling ? 'admin' : null,
            'cancelled_at':
                cancelling ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('id', appointmentId),
    );
  }

  @override
  Future<List<SalonClosure>> fetchClosures(DateTime from, DateTime to) async {
    final rows = await _guard(
      () => _client
          .from('salon_closures')
          .select()
          .gte('end_date', Slot(from, 0).dateKey)
          .lte('start_date', Slot(to, 0).dateKey)
          .order('start_date'),
    );

    return rows
        .cast<Map<String, dynamic>>()
        .map(SalonClosure.fromRow)
        .toList(growable: false);
  }

  @override
  Future<SalonClosure> addClosure({
    required DateTime from,
    required DateTime to,
    String? reason,
  }) async {
    final row = await _guard(
      () => _client
          .from('salon_closures')
          .insert({
            'start_date': Slot(from, 0).dateKey,
            'end_date': Slot(to, 0).dateKey,
            'reason': _blankToNull(reason),
          })
          .select()
          .single(),
    );

    return SalonClosure.fromRow(row);
  }

  @override
  Future<void> removeClosure(String closureId) async {
    // Soft, like everything else: the days reopen, the record of the decision
    // stays.
    await _guard(
      () => _client
          .from('salon_closures')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', closureId),
    );
  }

  @override
  Future<void> adminSignOut() => _client.auth.signOut();

  // --- internals -----------------------------------------------------------

  Future<String> _findOrCreateCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    final existing = await _guard(
      () => _client
          .from('customers')
          .select('id')
          .eq('phone', phone)
          .maybeSingle(),
    );

    if (existing != null) return existing['id'] as String;

    final created = await _guard(
      () => _client
          .from('customers')
          .insert({
            'first_name': firstName.trim(),
            'last_name': _blankToNull(lastName),
            'phone': phone,
            'created_by_admin': true,
          })
          .select('id')
          .single(),
    );

    return created['id'] as String;
  }

  Future<List<AppointmentService>> _lineItemsFor(String appointmentId) async {
    final rows = await _guard(
      () => _client
          .from('appointment_services')
          .select('service_id, kind, amount')
          .eq('appointment_id', appointmentId),
    );

    return rows
        .cast<Map<String, dynamic>>()
        .map(AppointmentService.fromRow)
        .toList(growable: false);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// A function returning a composite type arrives as the row itself; some
  /// client versions wrap it in a single-element list.
  static Map<String, dynamic> _single(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return (value.first as Map).cast<String, dynamic>();
    }
    if (value is Map) return value.cast<String, dynamic>();
    throw const BookingFailedException('The booking did not come back.');
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
        _bookingWindow => _bookingWindowFrom(error),
        _salonClosed => const SalonClosedException(),
        _cancelTooLate => const CancelTooLateException(),
        _nameMismatch => const NameDoesNotMatchException(),
        _notFound => BookingFailedException(
          'The app asked for something that is not there: ${error.message}',
        ),
        _checkViolation => BookingFailedException(
          'A value the app should have validated was rejected by the '
          'database: ${error.message}',
        ),
        _ => BookingFailedException('${error.code}: ${error.message}'),
      };

  /// The window trigger names the clashing date in its message, which is the
  /// difference between "you cannot book yet" and "you already have one on the
  /// 3rd, so the 24th is the earliest". Parsed leniently: a message that
  /// changes shape costs the detail, never the explanation.
  static BookingException _bookingWindowFrom(PostgrestException error) {
    final match = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(error.message);
    final existing = match == null ? null : DateTime.tryParse(match.group(1)!);

    return BookingWindowException(
      existingDate: existing,
      nextAvailable: existing?.add(const Duration(days: 21)),
    );
  }

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
