import 'package:flutter/foundation.dart';

import '../models/appointment.dart';

/// The in-progress booking, filled in step by step as the user moves through
/// calendar -> time -> details -> service -> review.
///
/// It is deliberately separate from [AppointmentProvider]: nothing here is
/// persisted until the user confirms on the review screen.
class BookingProvider extends ChangeNotifier {
  DateTime? _date;
  int? _hour;
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String? _serviceId;

  DateTime? get date => _date;
  int? get hour => _hour;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get phone => _phone;
  String? get serviceId => _serviceId;

  /// Slot start times offered by the salon: 10:00 to 20:00, every two hours.
  static const List<int> availableHours = [10, 12, 14, 16, 18, 20];

  /// The chosen slot as a single instant, or null until both date and hour
  /// have been picked.
  DateTime? get start {
    final date = _date;
    final hour = _hour;
    if (date == null || hour == null) return null;
    return DateTime(date.year, date.month, date.day, hour);
  }

  DateTime? get end => start?.add(kAppointmentDuration);

  /// Clears every field. Called whenever a new booking flow begins so a
  /// half-finished attempt never leaks into the next one.
  void reset() {
    _date = null;
    _hour = null;
    _firstName = '';
    _lastName = '';
    _phone = '';
    _serviceId = null;
    notifyListeners();
  }

  void selectDate(DateTime value) {
    // Normalise to midnight so date equality never trips over a time component.
    final normalised = DateTime(value.year, value.month, value.day);
    if (_date == normalised) return;
    _date = normalised;
    // A new day invalidates the slot chosen on the previous one.
    _hour = null;
    notifyListeners();
  }

  void selectHour(int value) {
    if (_hour == value) return;
    _hour = value;
    notifyListeners();
  }

  void setDetails({
    required String firstName,
    required String lastName,
    required String phone,
  }) {
    _firstName = firstName.trim();
    _lastName = lastName.trim();
    _phone = phone.trim();
    notifyListeners();
  }

  /// Passing null records "skipped", which is a valid outcome for this step.
  void selectService(String? id) {
    _serviceId = id;
    notifyListeners();
  }

  /// Builds the [Appointment] to persist. Only call once [start] is non-null.
  Appointment buildAppointment() {
    final slot = start;
    assert(slot != null, 'buildAppointment() called before a slot was chosen');
    return Appointment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      start: slot!,
      firstName: _firstName,
      lastName: _lastName,
      phone: _phone,
      serviceId: _serviceId,
    );
  }
}
