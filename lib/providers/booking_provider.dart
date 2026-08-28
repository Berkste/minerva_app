import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/slot.dart';
import '../utils/phone_formatter.dart';

/// The in-progress booking, filled in step by step as the user moves through
/// calendar -> time -> details -> service -> review.
///
/// Nothing here reaches Supabase until the customer confirms on the review
/// screen.
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

  /// Ten significant digits, no separators — the shape the database stores.
  String get phone => _phone;

  String? get serviceId => _serviceId;

  /// Slot start times offered by the salon: 10:00 to 20:00, every two hours.
  ///
  /// Must stay in step with the `slot_hour` check constraint in the database.
  static const List<int> availableHours = [10, 12, 14, 16, 18, 20];

  /// The chosen slot, or null until both date and hour have been picked.
  Slot? get slot {
    final date = _date;
    final hour = _hour;
    if (date == null || hour == null) return null;
    return Slot(date, hour);
  }

  DateTime? get start => slot?.start;
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

  /// Clears the chosen hour — used when the slot turns out to be taken.
  void clearHour() {
    if (_hour == null) return;
    _hour = null;
    notifyListeners();
  }

  void setDetails({
    required String firstName,
    required String lastName,
    required String phone,
  }) {
    _firstName = firstName.trim();
    _lastName = lastName.trim();
    // Store digits only; the mask is a display concern.
    _phone = TurkishPhoneInputFormatter.extractDigits(phone);
    notifyListeners();
  }

  /// Passing null records "skipped", which is a valid outcome for this step.
  void selectService(String? id) {
    _serviceId = id;
    notifyListeners();
  }
}
