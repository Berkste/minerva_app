import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/slot.dart';
import '../utils/phone_formatter.dart';

/// The in-progress booking, filled in step by step as the user moves through
/// calendar -> time -> service -> details -> review.
///
/// Nothing here reaches Supabase until the customer confirms on the review
/// screen.
///
/// The same draft also carries a *reschedule*: moving an existing booking is
/// the same two choices — a day and an hour — against the same availability
/// and the same rules, so it reuses the calendar and the time grid rather than
/// growing a second pair of screens that would drift from them.
class BookingProvider extends ChangeNotifier {
  DateTime? _date;
  int? _hour;
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String? _serviceId;
  String? _reschedulingId;

  DateTime? get date => _date;
  int? get hour => _hour;
  String get firstName => _firstName;
  String get lastName => _lastName;

  /// Ten significant digits, no separators — the shape the database stores.
  String get phone => _phone;

  String? get serviceId => _serviceId;

  /// The booking being moved, or null when this is a new one.
  String? get reschedulingId => _reschedulingId;

  bool get isRescheduling => _reschedulingId != null;

  /// Slot start times offered by the salon. Lives on [Slot]; kept here as the
  /// name the booking screens already use.
  static const List<int> availableHours = Slot.salonHours;

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
    _reschedulingId = null;
    notifyListeners();
  }

  /// Starts moving [appointment], opening on the day it currently sits on.
  ///
  /// The contact details come along untouched: rescheduling changes when
  /// somebody is coming, not who they are.
  void beginReschedule(Appointment appointment) {
    _reschedulingId = appointment.id;
    _date = DateTime(
      appointment.slot.date.year,
      appointment.slot.date.month,
      appointment.slot.date.day,
    );
    _hour = appointment.slot.hour;
    _firstName = appointment.firstName;
    _lastName = appointment.lastName ?? '';
    _phone = appointment.phone;
    _serviceId = appointment.mainService?.serviceId;
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
