import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../services/storage_service.dart';

/// Owns the list of confirmed appointments and keeps local storage in sync.
class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider({StorageService? storage})
      : _storage = storage ?? StorageService();

  final StorageService _storage;

  List<Appointment> _appointments = [];
  bool _isLoading = true;

  /// All appointments, soonest first.
  List<Appointment> get appointments => List.unmodifiable(_appointments);

  /// True until the first read from storage completes.
  bool get isLoading => _isLoading;

  /// Appointments that have not finished yet, soonest first.
  List<Appointment> get upcoming {
    final now = DateTime.now();
    return _appointments.where((a) => a.isUpcoming(now: now)).toList();
  }

  /// Appointments already in the past, most recent first.
  List<Appointment> get past {
    final now = DateTime.now();
    return _appointments.where((a) => !a.isUpcoming(now: now)).toList().reversed
        .toList();
  }

  /// The next appointment the user will attend, or null if none is booked.
  Appointment? get nextAppointment =>
      upcoming.isEmpty ? null : upcoming.first;

  /// Reads persisted appointments. Safe to call more than once.
  Future<void> load() async {
    _appointments = _sorted(await _storage.loadAppointments());
    _isLoading = false;
    notifyListeners();
  }

  /// Returns true when [start] is already taken, so the time grid can grey the
  /// slot out instead of double-booking it.
  bool isSlotTaken(DateTime start) =>
      _appointments.any((a) => a.start.isAtSameMomentAs(start));

  Future<void> add(Appointment appointment) async {
    _appointments = _sorted([..._appointments, appointment]);
    notifyListeners();
    await _storage.saveAppointments(_appointments);
  }

  Future<void> remove(String id) async {
    _appointments = _appointments.where((a) => a.id != id).toList();
    notifyListeners();
    await _storage.saveAppointments(_appointments);
  }

  static List<Appointment> _sorted(List<Appointment> list) {
    final copy = [...list]..sort((a, b) => a.start.compareTo(b.start));
    return copy;
  }
}
