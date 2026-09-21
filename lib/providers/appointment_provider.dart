import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/customer.dart';
import '../models/slot.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../services/local_cache.dart';

/// What the appointment list is currently doing.
enum LoadState { loading, ready, failed }

/// Owns this device's bookings and the person they belong to.
///
/// Supabase is the source of truth. The local cache only fills in when a
/// refresh fails, so the customer still sees their next appointment offline.
class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider(this._repository, {LocalCache? cache})
      : _cache = cache ?? LocalCache();

  final BookingRepository _repository;
  final LocalCache _cache;

  List<Appointment> _appointments = [];
  Customer? _customer;
  LoadState _state = LoadState.loading;
  BookingException? _error;

  /// True when the list on screen came from the cache rather than the server.
  bool _isStale = false;

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  Customer? get customer => _customer;
  LoadState get state => _state;
  BookingException? get error => _error;
  bool get isStale => _isStale;

  bool get isLoading => _state == LoadState.loading;

  /// Bookings that still stand and have not finished, soonest first.
  List<Appointment> get upcoming {
    final now = DateTime.now();
    return _appointments.where((a) => a.isUpcoming(now: now)).toList();
  }

  /// Finished bookings, most recent first. Cancelled ones are not shown.
  List<Appointment> get past {
    final now = DateTime.now();
    return _appointments
        .where((a) => !a.isCancelled && !a.isUpcoming(now: now))
        .toList()
        .reversed
        .toList();
  }

  Appointment? get nextAppointment => upcoming.isEmpty ? null : upcoming.first;

  /// Loads this device's bookings and the person they belong to.
  ///
  /// Does NOT sign in. Opening the app creates nothing in the database — a
  /// device without a session simply has no bookings and no customer record,
  /// and the repository answers both without a round trip. The identity is
  /// created on the first real action (see [book]).
  Future<void> load() async {
    _state = LoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchMyAppointments(),
        _repository.currentCustomer(),
      ]);

      _appointments = _sorted(results[0] as List<Appointment>);
      _customer = results[1] as Customer?;
      _isStale = false;
      _state = LoadState.ready;
      _error = null;

      // Refresh the offline copy.
      await _cache.writeAppointments(_appointments);
      await _cache.writeCustomer(_customer);
    } on BookingException catch (failure) {
      // Fall back to whatever was last seen, and say so.
      _appointments = _sorted(await _cache.readAppointments());
      _customer = await _cache.readCustomer();
      _isStale = true;
      _error = failure;
      _state = _appointments.isEmpty ? LoadState.failed : LoadState.ready;
    }

    notifyListeners();
  }

  /// Books [slot], creating or claiming the customer in the same call.
  ///
  /// Rethrows the rule the customer hit — [SlotTakenException] when somebody
  /// else got there first, [BookingWindowException] when they already have one
  /// within three weeks, [SalonClosedException], [NameDoesNotMatchException] —
  /// so the review screen can say which, rather than "something went wrong".
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    String? lastName,
    required String phone,
    String? serviceId,
  }) async {
    final appointment = await _repository.book(
      slot: slot,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      serviceId: serviceId,
    );

    _appointments = _sorted([..._appointments, appointment]);
    notifyListeners();

    // The booking is what matters. Reading the customer back is how the
    // profile screen learns who this device now is, but failing to is not
    // worth undoing a confirmed appointment over.
    try {
      _customer = await _repository.currentCustomer();
      await _cache.writeCustomer(_customer);
    } on BookingException {
      // Left for the next load to pick up.
    }

    await _cache.writeAppointments(_appointments);
    notifyListeners();

    return appointment;
  }

  /// Saves the customer's own contact details.
  ///
  /// The profile screen's Save. On a device that has never booked this creates
  /// the person, which is the same thing booking does — there is no separate
  /// act of registering.
  Future<Customer> saveCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  }) async {
    final customer = await _repository.updateCustomer(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    _customer = customer;
    await _cache.writeCustomer(customer);
    notifyListeners();
    return customer;
  }

  /// Moves a booking to a different slot.
  Future<Appointment> reschedule(String appointmentId, Slot slot) async {
    final updated = await _repository.reschedule(appointmentId, slot);

    _appointments = _sorted([
      for (final a in _appointments)
        if (a.id == appointmentId) updated else a,
    ]);
    await _cache.writeAppointments(_appointments);
    notifyListeners();
    return updated;
  }

  /// Changes the treatment on a booking; null clears it.
  Future<void> setTreatment(String appointmentId, String? serviceId) async {
    await _repository.setTreatment(appointmentId, serviceId);
    await load();
  }

  /// Cancels a booking, which releases its slot for someone else.
  Future<void> cancel(String appointmentId) async {
    await _repository.cancel(appointmentId);

    _appointments = _appointments
        .map(
          (a) => a.id == appointmentId
              ? a.copyWith(status: AppointmentStatus.cancelled)
              : a,
        )
        .toList();

    notifyListeners();
    await _cache.writeAppointments(_appointments);
  }

  static List<Appointment> _sorted(List<Appointment> list) {
    final copy = [...list]..sort((a, b) => a.start.compareTo(b.start));
    return copy;
  }
}
