import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/profile.dart';
import '../models/slot.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../services/local_cache.dart';

/// What the appointment list is currently doing.
enum LoadState { loading, ready, failed }

/// Owns the signed-in user's bookings and their saved profile.
///
/// Supabase is the source of truth. The local cache only fills in when a
/// refresh fails, so the customer still sees their next appointment offline.
class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider(this._repository, {LocalCache? cache})
      : _cache = cache ?? LocalCache();

  final BookingRepository _repository;
  final LocalCache _cache;

  List<Appointment> _appointments = [];
  Profile? _profile;
  LoadState _state = LoadState.loading;
  BookingException? _error;

  /// True when the list on screen came from the cache rather than the server.
  bool _isStale = false;

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  Profile? get profile => _profile;
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

  /// Signs in, then loads bookings and profile. Safe to call more than once.
  Future<void> load() async {
    _state = LoadState.loading;
    _error = null;
    notifyListeners();

    try {
      await _repository.ensureSignedIn();

      final results = await Future.wait([
        _repository.fetchMyAppointments(),
        _repository.fetchProfile(),
      ]);

      _appointments = _sorted(results[0] as List<Appointment>);
      _profile = results[1] as Profile?;
      _isStale = false;
      _state = LoadState.ready;
      _error = null;

      // Refresh the offline copy.
      await _cache.writeAppointments(_appointments);
      await _cache.writeProfile(_profile);
    } on BookingException catch (failure) {
      // Fall back to whatever was last seen, and say so.
      _appointments = _sorted(await _cache.readAppointments());
      _profile = await _cache.readProfile();
      _isStale = true;
      _error = failure;
      _state = _appointments.isEmpty ? LoadState.failed : LoadState.ready;
    }

    notifyListeners();
  }

  /// Books [slot] and records the customer's details on their profile.
  ///
  /// Rethrows [SlotTakenException] when someone else got there first, so the
  /// review screen can send the customer back to pick another time.
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    required String lastName,
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

    // The booking is what matters; a profile write that fails must not undo
    // it or block the confirmation screen.
    try {
      _profile = await _repository.saveProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      await _cache.writeProfile(_profile);
    } on BookingException {
      // Left for the next successful booking to write.
    }

    await _cache.writeAppointments(_appointments);
    notifyListeners();

    return appointment;
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
