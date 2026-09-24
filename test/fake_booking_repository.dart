import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/customer.dart';
import 'package:minerva_app/models/salon_closure.dart';
import 'package:minerva_app/models/salon_service.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/services/booking_exception.dart';
import 'package:minerva_app/services/booking_repository.dart';

/// In-memory stand-in for Supabase.
///
/// It reproduces the rules the real schema enforces and the app depends on,
/// because every one of them lives in the database rather than in Dart — and a
/// fake that is more permissive than the real thing lets tests pass over
/// behaviour that would fail in production:
///
///   · one confirmed booking per slot        (the partial unique index)
///   · nothing in the past                   (MN001)
///   · one visit per 21 days, symmetric      (MN002)
///   · closed on Sundays and declared days   (MN003)
///   · no customer cancellation inside an hour (MN004)
///   · a claimed record must match on name   (MN005)
///
/// Staff bypass the middle four, exactly as they do in the database.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({this.deviceId = 'device-1'});

  /// Stands in for `auth.uid()` — a device, not a person.
  final String deviceId;

  /// Everybody the salon knows.
  final List<Customer> customers = [];

  /// Every booking, from every customer.
  final List<Appointment> appointments = [];

  /// Declared closures. Sundays are a standing rule, not one of these.
  final List<SalonClosure> closures = [];

  /// The catalogue. Two entries by default so a test can pick one and swap it.
  List<SalonService> treatments = const [
    SalonService(
      id: 'medikal_manikur',
      kind: ServiceKind.main,
      nameTr: 'Medikal Manikür',
      nameEn: 'Medical Manicure',
      priceMin: 450,
      sortOrder: 10,
    ),
    SalonService(
      id: 'protez_tirnak',
      kind: ServiceKind.main,
      nameTr: 'Protez Tırnak',
      nameEn: 'Artificial Nails',
      priceMin: 1000,
      sortOrder: 20,
    ),
  ];

  /// Ids of archived customers. Nothing is really deleted here either, so
  /// "deleted" is a set rather than a removal.
  final Set<String> archived = {};

  /// Ids of services taken off the menu.
  final Set<String> inactiveServices = {};

  bool signedIn = false;
  int bookCallCount = 0;

  /// The customer this device is linked to, once it has booked.
  String? linkedCustomerId;

  /// Set to make the next call of each kind fail, for testing error paths.
  BookingException? failOnLoad;
  BookingException? failOnBook;
  BookingException? failOnAvailability;

  /// Runs just before an insert is committed. Lets a test slip another
  /// booking in at exactly the wrong moment.
  Future<void> Function()? onBeforeBook;

  // --- Admin test knobs ----------------------------------------------------
  String validAdminEmail = 'admin@minerva.test';
  String validAdminPassword = 'correct-horse';

  /// Whether those valid credentials actually belong to a staff member. Set
  /// false to test the "authenticated but not authorized" path.
  bool credentialsAreAdmin = true;

  bool _adminSignedIn = false;
  int _nextId = 1;

  @override
  String? get currentUserId => signedIn ? deviceId : null;

  @override
  Future<void> ensureSignedIn() async => signedIn = true;

  // --- the person ----------------------------------------------------------

  @override
  Future<Customer?> currentCustomer() async {
    final failure = failOnLoad;
    if (failure != null) throw failure;
    if (!signedIn) return null;
    return _customerById(linkedCustomerId);
  }

  @override
  Future<Customer> claimCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    await ensureSignedIn();

    final existing = _customerByPhone(phone);
    if (existing != null) {
      // The one check standing between a phone number and the record behind
      // it. Case and surrounding space are forgiven; nothing else is.
      if (existing.firstName.trim().toLowerCase() !=
          firstName.trim().toLowerCase()) {
        throw const NameDoesNotMatchException();
      }
      linkedCustomerId = existing.id;
      return existing;
    }

    final created = Customer(
      id: 'cust-${_nextId++}',
      firstName: firstName.trim(),
      lastName: _blankToNull(lastName),
      phone: phone,
    );
    customers.add(created);
    linkedCustomerId = created.id;
    return created;
  }

  @override
  Future<Customer> updateCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    await ensureSignedIn();

    final existing = _customerById(linkedCustomerId);
    if (existing == null) {
      return claimCustomer(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
    }

    final updated = existing.copyWith(
      firstName: firstName.trim(),
      lastName: _blankToNull(lastName),
      clearLastName: _blankToNull(lastName) == null,
      phone: phone,
    );
    customers[customers.indexWhere((c) => c.id == existing.id)] = updated;
    return updated;
  }

  // --- browsing ------------------------------------------------------------

  @override
  Future<Set<Slot>> fetchBookedSlots(DateTime from, DateTime to) async {
    final failure = failOnAvailability;
    if (failure != null) throw failure;

    final fromDay = _dayOf(from);
    final toDay = _dayOf(to);

    return appointments
        .where(_holdsItsSlot)
        .map((a) => a.slot)
        .where((s) => !s.date.isBefore(fromDay) && !s.date.isAfter(toDay))
        .toSet();
  }

  @override
  Future<Set<DateTime>> fetchClosedDays(DateTime from, DateTime to) async {
    final failure = failOnAvailability;
    if (failure != null) throw failure;

    final days = <DateTime>{};
    for (var day = _dayOf(from);
        !day.isAfter(_dayOf(to));
        day = day.add(const Duration(days: 1))) {
      if (_isClosed(day)) days.add(day);
    }
    return days;
  }

  @override
  Future<List<SalonService>> fetchTreatments() async {
    final failure = failOnLoad;
    if (failure != null) throw failure;
    return treatments;
  }

  // --- this device's bookings ---------------------------------------------

  @override
  Future<List<Appointment>> fetchMyAppointments() async {
    final failure = failOnLoad;
    if (failure != null) throw failure;

    // Mirrors the real repository: no session means no identity, so no
    // bookings — and crucially, no sign-in triggered by a mere read.
    if (!signedIn || linkedCustomerId == null) return const <Appointment>[];

    final today = _dayOf(DateTime.now());

    // Mirrors the select policy: a claimed record shows only what is still
    // ahead, unless this device is the one that booked it.
    return appointments
        .where((a) =>
            a.customerId == linkedCustomerId &&
            (!a.slot.date.isBefore(today) || _bookedHere.contains(a.id)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    String? lastName,
    required String phone,
    String? serviceId,
  }) async {
    bookCallCount++;

    final failure = failOnBook;
    if (failure != null) throw failure;

    // Booking is what creates the identity, exactly as in the real repository.
    final customer = await claimCustomer(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    _checkRules(slot: slot, customerId: customer.id, asAdmin: false);

    await onBeforeBook?.call();

    // The unique index, in miniature. Checked after the hook so a test can
    // take the slot in between, which is the race this exists to reproduce.
    _checkSlotFree(slot);

    final appointment = Appointment(
      id: 'appt-${_nextId++}',
      customerId: customer.id,
      slot: slot,
      firstName: firstName.trim(),
      lastName: _blankToNull(lastName),
      phone: phone,
      services: _lineFor(serviceId),
      createdAt: DateTime.now(),
    );

    appointments.add(appointment);
    _bookedHere.add(appointment.id);
    return appointment;
  }

  @override
  Future<Appointment> reschedule(String appointmentId, Slot slot) async {
    final index = appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) {
      throw const BookingFailedException('No such appointment.');
    }

    final existing = appointments[index];
    if (existing.createdByAdmin) {
      throw const BookingFailedException('Not this device\'s to change.');
    }

    _checkRules(
      slot: slot,
      customerId: existing.customerId,
      asAdmin: false,
      ignoring: appointmentId,
    );
    _checkSlotFree(slot, ignoring: appointmentId);

    final moved = existing.copyWith(slot: slot);
    appointments[index] = moved;
    return moved;
  }

  @override
  Future<void> setTreatment(String appointmentId, String? serviceId) async {
    final index = appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;
    appointments[index] =
        appointments[index].copyWith(services: _lineFor(serviceId));
  }

  @override
  Future<void> cancel(String appointmentId) async {
    final index = appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final existing = appointments[index];

    // MN004: the salon keeps the last hour. Staff are not bound by it.
    if (!await isCurrentUserAdmin() &&
        !existing.start
            .subtract(const Duration(hours: 1))
            .isAfter(DateTime.now())) {
      throw const CancelTooLateException();
    }

    appointments[index] = existing.copyWith(
      status: AppointmentStatus.cancelled,
      cancelledBy: CancelledBy.customer,
    );
  }

  // --- Admin / employee ----------------------------------------------------

  @override
  Future<void> adminSignIn({
    required String email,
    required String password,
  }) async {
    if (email.trim() != validAdminEmail || password != validAdminPassword) {
      throw const InvalidAdminCredentialsException();
    }
    _adminSignedIn = true;
    if (!credentialsAreAdmin) {
      await adminSignOut();
      throw const NotAnAdminException();
    }
  }

  @override
  Future<bool> isCurrentUserAdmin() async =>
      _adminSignedIn && credentialsAreAdmin;

  @override
  Future<List<Appointment>> fetchAppointmentsInRange(
    DateTime from,
    DateTime to,
  ) async {
    final failure = failOnLoad;
    if (failure != null) throw failure;

    // Mirrors RLS: a non-staff caller sees nothing, not everyone's rows.
    if (!await isCurrentUserAdmin()) return [];

    final fromDay = _dayOf(from);
    final toDay = _dayOf(to);

    return appointments
        .where((a) =>
            !a.isCancelled &&
            !a.slot.date.isBefore(fromDay) &&
            !a.slot.date.isAfter(toDay))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<Appointment> adminBook({
    required Slot slot,
    required String firstName,
    String? lastName,
    required String phone,
    String? serviceId,
  }) async {
    if (!await isCurrentUserAdmin()) {
      throw const NotAnAdminException();
    }

    var customer = _customerByPhone(phone);
    if (customer == null) {
      customer = Customer(
        id: 'cust-${_nextId++}',
        firstName: firstName.trim(),
        lastName: _blankToNull(lastName),
        phone: phone,
        createdByAdmin: true,
      );
      customers.add(customer);
    }

    // Staff are exempt from the window and from closed days, but not from the
    // slot being free or the past being past.
    _checkSlotFree(slot);

    final appointment = Appointment(
      id: 'appt-${_nextId++}',
      customerId: customer.id,
      slot: slot,
      firstName: firstName.trim(),
      lastName: _blankToNull(lastName),
      phone: phone,
      services: _lineFor(serviceId),
      createdByAdmin: true,
      createdAt: DateTime.now(),
    );

    appointments.add(appointment);
    return appointment;
  }

  @override
  Future<void> adminSetStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    if (!await isCurrentUserAdmin()) return;
    final index = appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    appointments[index] = appointments[index].copyWith(
      status: status,
      cancelledBy:
          status == AppointmentStatus.cancelled ? CancelledBy.admin : null,
    );
  }

  @override
  Future<List<SalonClosure>> fetchClosures(DateTime from, DateTime to) async {
    final fromDay = _dayOf(from);
    final toDay = _dayOf(to);
    return closures
        .where((c) => !c.endDate.isBefore(fromDay) && !c.startDate.isAfter(toDay))
        .toList();
  }

  @override
  Future<SalonClosure> addClosure({
    required DateTime from,
    required DateTime to,
    String? reason,
  }) async {
    if (!await isCurrentUserAdmin()) {
      throw const NotAnAdminException();
    }
    final closure = SalonClosure(
      id: 'closure-${_nextId++}',
      startDate: _dayOf(from),
      endDate: _dayOf(to),
      reason: reason,
    );
    closures.add(closure);
    return closure;
  }

  @override
  Future<void> removeClosure(String closureId) async {
    if (!await isCurrentUserAdmin()) return;
    closures.removeWhere((c) => c.id == closureId);
  }

  @override
  Future<List<Customer>> fetchCustomers({
    String? query,
    bool includeArchived = false,
  }) async {
    if (!await isCurrentUserAdmin()) return const [];

    final needle = (query ?? '').trim().toLowerCase();

    return customers.where((c) {
      if (!includeArchived && archived.contains(c.id)) return false;
      if (needle.isEmpty) return true;
      return c.firstName.toLowerCase().contains(needle) ||
          (c.lastName ?? '').toLowerCase().contains(needle) ||
          c.phone.contains(needle);
    }).toList();
  }

  @override
  Future<Customer> adminUpdateCustomer({
    required String customerId,
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    if (!await isCurrentUserAdmin()) throw const NotAnAdminException();

    final index = customers.indexWhere((c) => c.id == customerId);
    if (index == -1) {
      throw const BookingFailedException('No such customer.');
    }

    final updated = customers[index].copyWith(
      firstName: firstName.trim(),
      lastName: _blankToNull(lastName),
      clearLastName: _blankToNull(lastName) == null,
      phone: phone,
    );
    customers[index] = updated;
    return updated;
  }

  @override
  Future<void> setCustomerArchived(String customerId, bool archived_) async {
    if (!await isCurrentUserAdmin()) return;
    if (archived_) {
      archived.add(customerId);
    } else {
      archived.remove(customerId);
    }
  }

  @override
  Future<List<SalonService>> fetchCatalogue() async => treatments;

  @override
  Future<SalonService> saveService(SalonService service) async {
    if (!await isCurrentUserAdmin()) throw const NotAnAdminException();

    final index = treatments.indexWhere((s) => s.id == service.id);
    final next = [...treatments];
    if (index == -1) {
      next.add(service);
    } else {
      next[index] = service;
    }
    treatments = next;
    return service;
  }

  @override
  Future<void> setServiceActive(String serviceId, bool isActive) async {
    if (!await isCurrentUserAdmin()) return;
    if (isActive) {
      inactiveServices.remove(serviceId);
    } else {
      inactiveServices.add(serviceId);
    }
  }

  @override
  Future<void> addLineItem({
    required String appointmentId,
    required String serviceId,
    num? amount,
  }) async {
    if (!await isCurrentUserAdmin()) throw const NotAnAdminException();

    final index = appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    SalonService? service;
    for (final candidate in treatments) {
      if (candidate.id == serviceId) service = candidate;
    }
    if (service == null) {
      throw const BookingFailedException('No such service.');
    }

    final line = AppointmentService(
      id: 'line-${_nextId++}',
      serviceId: service.id,
      kind: service.kind,
      amount: amount ?? service.priceMin,
      service: service,
    );

    appointments[index] = appointments[index].copyWith(
      services: [...appointments[index].services, line],
    );
  }

  @override
  Future<void> removeLineItem(String lineItemId) async {
    if (!await isCurrentUserAdmin()) return;

    for (var i = 0; i < appointments.length; i++) {
      final lines = appointments[i].services;
      if (lines.any((l) => l.id == lineItemId)) {
        appointments[i] = appointments[i].copyWith(
          services: lines.where((l) => l.id != lineItemId).toList(),
        );
        return;
      }
    }
  }

  @override
  Future<void> adminSignOut() async => _adminSignedIn = false;

  // --- test helpers --------------------------------------------------------

  /// Books as a different customer — used to occupy a slot from "outside".
  Appointment bookAsSomeoneElse(Slot slot, {String phone = '5559998877'}) {
    var customer = _customerByPhone(phone);
    if (customer == null) {
      customer = Customer(
        id: 'cust-${_nextId++}',
        firstName: 'Other',
        lastName: 'Customer',
        phone: phone,
      );
      customers.add(customer);
    }

    final appointment = Appointment(
      id: 'appt-${_nextId++}',
      customerId: customer.id,
      slot: slot,
      firstName: customer.firstName,
      lastName: customer.lastName,
      phone: customer.phone,
    );
    appointments.add(appointment);
    return appointment;
  }

  // --- internals -----------------------------------------------------------

  /// Ids this device booked, which is what lets it still see them once they
  /// are in the past.
  final Set<String> _bookedHere = {};

  /// Everything the database would check before letting a booking stand.
  void _checkRules({
    required Slot slot,
    required String customerId,
    required bool asAdmin,
    String? ignoring,
  }) {
    // MN001 — the past is the past, for everybody.
    if (!slot.start.isAfter(DateTime.now())) {
      throw const SlotInThePastException();
    }

    if (asAdmin) return;

    // MN003 — Sundays and declared closures.
    if (_isClosed(slot.date)) throw const SalonClosedException();

    // MN002 — one visit per 21 days, symmetric, counting only the bookings
    // that still stand. A cancellation or a no-show releases the window.
    for (final other in appointments) {
      if (other.customerId != customerId) continue;
      if (other.id == ignoring) continue;
      if (!_holdsItsSlot(other)) continue;

      final gap = other.slot.date.difference(slot.date).inDays.abs();
      if (gap < 21) {
        throw BookingWindowException(
          existingDate: other.slot.date,
          nextAvailable: other.slot.date.add(const Duration(days: 21)),
        );
      }
    }
  }

  void _checkSlotFree(Slot slot, {String? ignoring}) {
    final taken = appointments.any(
      (a) => a.id != ignoring && _holdsItsSlot(a) && a.slot == slot,
    );
    if (taken) throw const SlotTakenException();
  }

  /// Whether a booking still occupies its slot — and, by the same token,
  /// still consumes its customer's window.
  static bool _holdsItsSlot(Appointment a) =>
      a.status == AppointmentStatus.confirmed ||
      a.status == AppointmentStatus.completed;

  bool _isClosed(DateTime day) {
    final d = _dayOf(day);
    if (d.weekday == DateTime.sunday) return true;
    return closures.any((c) => c.covers(d));
  }

  List<AppointmentService> _lineFor(String? serviceId) {
    if (serviceId == null) return const [];
    for (final service in treatments) {
      if (service.id == serviceId) {
        return [
          AppointmentService(
            serviceId: service.id,
            kind: ServiceKind.main,
            amount: service.priceMin,
            service: service,
          ),
        ];
      }
    }
    return const [];
  }

  Customer? _customerById(String? id) {
    if (id == null) return null;
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Customer? _customerByPhone(String phone) {
    for (final c in customers) {
      if (c.phone == phone) return c;
    }
    return null;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
