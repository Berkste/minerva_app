import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../utils/formatting.dart' show isSameDay;
import 'appointment_provider.dart' show LoadState;

/// Where the admin session is in its lifecycle.
enum AdminAuthState { signedOut, authenticating, authenticated }

/// Drives the admin/employee flow: staff sign-in, then a day-by-day view of
/// the salon-wide schedule.
///
/// Separate from [AppointmentProvider], which owns a single customer's own
/// bookings. This one only ever holds data a staff caller is allowed to see,
/// and every method it calls is gated by the database's `is_admin()` policies.
///
/// The schedule is loaded a month at a time: one date-range fetch gives both
/// the calendar's per-day markers and the selected day's appointment list, so
/// paging to another month is a single round trip.
class AdminProvider extends ChangeNotifier {
  AdminProvider(this._repository);

  final BookingRepository _repository;

  AdminAuthState _auth = AdminAuthState.signedOut;
  BookingException? _authError;

  DateTime _visibleMonth = _monthOf(DateTime.now());
  DateTime _selectedDay = _dayOf(DateTime.now());

  /// Confirmed appointments for [_visibleMonth], from every customer.
  List<Appointment> _monthAppointments = [];
  LoadState _listState = LoadState.loading;
  BookingException? _listError;

  AdminAuthState get auth => _auth;
  BookingException? get authError => _authError;

  DateTime get visibleMonth => _visibleMonth;
  DateTime get selectedDay => _selectedDay;
  LoadState get listState => _listState;
  BookingException? get listError => _listError;

  /// Confirmed appointments on [day], soonest first.
  List<Appointment> appointmentsOn(DateTime day) => _monthAppointments
      .where((a) => isSameDay(a.start, day))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  /// The list under the calendar: the selected day's appointments.
  List<Appointment> get selectedDayAppointments =>
      appointmentsOn(_selectedDay);

  /// Day-normalised dates in the visible month that have at least one
  /// appointment — the calendar puts a marker under each.
  Set<DateTime> get daysWithAppointments =>
      _monthAppointments.map((a) => _dayOf(a.start)).toSet();

  /// Signs in as staff and, on success, opens on today.
  ///
  /// Returns true when the caller is now an authenticated admin. On failure it
  /// stays signed out and exposes the reason through [authError].
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _auth = AdminAuthState.authenticating;
    _authError = null;
    notifyListeners();

    try {
      await _repository.adminSignIn(email: email, password: password);
      _auth = AdminAuthState.authenticated;
      // Land on today, in today's month.
      final now = DateTime.now();
      _selectedDay = _dayOf(now);
      _visibleMonth = _monthOf(now);
      notifyListeners();
      await loadMonth(_visibleMonth);
      return true;
    } on BookingException catch (failure) {
      _auth = AdminAuthState.signedOut;
      _authError = failure;
      notifyListeners();
      return false;
    }
  }

  /// Loads every confirmed appointment in [month] across all customers.
  Future<void> loadMonth(DateTime month) async {
    _visibleMonth = _monthOf(month);
    _listState = LoadState.loading;
    _listError = null;
    notifyListeners();

    final first = _visibleMonth;
    final last = DateTime(first.year, first.month + 1, 0);

    try {
      _monthAppointments =
          await _repository.fetchAppointmentsInRange(first, last);
      _listState = LoadState.ready;
    } on BookingException catch (failure) {
      _monthAppointments = [];
      _listError = failure;
      _listState = LoadState.failed;
    }
    notifyListeners();
  }

  /// Pages the calendar to another month (delta in months) and reloads it.
  Future<void> showMonth(int delta) {
    final target = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    return loadMonth(target);
  }

  /// Selects a day within the visible month; the list below updates.
  void selectDay(DateTime day) {
    final normalised = _dayOf(day);
    if (normalised == _selectedDay) return;
    _selectedDay = normalised;
    notifyListeners();
  }

  /// Cancels any customer's appointment and drops it from the loaded month.
  ///
  /// Staff are not bound by the hour-before deadline a customer has: the salon
  /// is the one who knows the chair is free.
  Future<void> cancel(String appointmentId) =>
      setStatus(appointmentId, AppointmentStatus.cancelled);

  /// Marks a booking as it actually went.
  ///
  /// Two of these change more than a label. Cancelling frees the slot, and a
  /// no-show frees both the slot *and* that customer's 21-day window — the
  /// person did not come, so they are not held to having been.
  Future<void> setStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    await _repository.adminSetStatus(appointmentId, status);

    if (status == AppointmentStatus.cancelled) {
      // A cancelled booking leaves the schedule entirely; the day should stop
      // showing a marker for it.
      _monthAppointments =
          _monthAppointments.where((a) => a.id != appointmentId).toList();
    } else {
      _monthAppointments = _monthAppointments
          .map((a) => a.id == appointmentId ? a.copyWith(status: status) : a)
          .toList();
    }

    notifyListeners();
  }

  /// Ends the staff session and drops the loaded schedule.
  Future<void> signOut() async {
    await _repository.adminSignOut();
    _auth = AdminAuthState.signedOut;
    _monthAppointments = [];
    _listState = LoadState.loading;
    _listError = null;
    notifyListeners();
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);
}
