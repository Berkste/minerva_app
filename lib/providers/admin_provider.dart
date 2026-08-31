import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import 'appointment_provider.dart' show LoadState;

/// Where the admin session is in its lifecycle.
enum AdminAuthState { signedOut, authenticating, authenticated }

/// Drives the admin/employee flow: staff sign-in, then the salon-wide
/// appointment list.
///
/// Separate from [AppointmentProvider], which owns a single customer's own
/// bookings. This one only ever holds data a staff caller is allowed to see,
/// and every method it calls is gated by the database's `is_admin()` policies.
class AdminProvider extends ChangeNotifier {
  AdminProvider(this._repository);

  final BookingRepository _repository;

  AdminAuthState _auth = AdminAuthState.signedOut;
  BookingException? _authError;

  List<Appointment> _appointments = [];
  LoadState _listState = LoadState.loading;
  BookingException? _listError;

  AdminAuthState get auth => _auth;
  BookingException? get authError => _authError;

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  LoadState get listState => _listState;
  BookingException? get listError => _listError;

  /// Signs in as staff and, on success, loads the schedule.
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
      notifyListeners();
      await loadAppointments();
      return true;
    } on BookingException catch (failure) {
      _auth = AdminAuthState.signedOut;
      _authError = failure;
      notifyListeners();
      return false;
    }
  }

  /// Ends the staff session and drops the loaded schedule.
  Future<void> signOut() async {
    await _repository.adminSignOut();
    _auth = AdminAuthState.signedOut;
    _appointments = [];
    _listState = LoadState.loading;
    _listError = null;
    notifyListeners();
  }

  /// Loads every upcoming appointment across all customers.
  Future<void> loadAppointments() async {
    _listState = LoadState.loading;
    _listError = null;
    notifyListeners();

    try {
      _appointments = await _repository.fetchAllUpcomingAppointments();
      _listState = LoadState.ready;
    } on BookingException catch (failure) {
      _appointments = [];
      _listError = failure;
      _listState = LoadState.failed;
    }
    notifyListeners();
  }

  /// Cancels any customer's appointment and drops it from the list.
  Future<void> cancel(String appointmentId) async {
    await _repository.adminCancel(appointmentId);
    _appointments =
        _appointments.where((a) => a.id != appointmentId).toList();
    notifyListeners();
  }
}
