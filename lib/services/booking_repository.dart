import '../models/appointment.dart';
import '../models/profile.dart';
import '../models/slot.dart';

/// Everything the app needs from the backend.
///
/// An interface rather than a concrete class so the whole booking flow can be
/// driven by an in-memory fake in tests — including the double-booking race,
/// which is otherwise awkward to reproduce.
abstract interface class BookingRepository {
  /// Id of the signed-in user, or null before sign-in completes.
  String? get currentUserId;

  /// Signs in anonymously if there is no session yet. Safe to call repeatedly.
  Future<void> ensureSignedIn();

  /// This device's bookings, soonest first.
  Future<List<Appointment>> fetchMyAppointments();

  /// Slots already taken between [from] and [to], inclusive.
  ///
  /// Returns slot keys for *everyone's* bookings — that is the point, so the
  /// grid can grey out unavailable times — but never any customer details.
  Future<Set<Slot>> fetchBookedSlots(DateTime from, DateTime to);

  /// Writes the booking.
  ///
  /// Throws [SlotTakenException] if another booking for the same slot has
  /// already been committed.
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    required String lastName,
    required String phone,
    String? serviceId,
  });

  /// Marks a booking cancelled, which releases its slot for someone else.
  Future<void> cancel(String appointmentId);

  /// This device's saved contact details, or null while still a guest.
  Future<Profile?> fetchProfile();

  /// Creates or updates the profile — how a guest becomes a known customer.
  Future<Profile> saveProfile({
    required String firstName,
    required String lastName,
    required String phone,
  });

  // --- Admin / employee ----------------------------------------------------
  // These succeed only for a caller the database recognises as staff. The
  // authorization is enforced by RLS (the `is_admin()` policies), not by the
  // app; the methods here are just how the admin screens reach it.

  /// Signs in a staff member with email + password and confirms they are
  /// actually an admin.
  ///
  /// Throws [InvalidAdminCredentialsException] when the email/password is
  /// wrong, and [NotAnAdminException] when the credentials are valid but the
  /// account is not staff (in which case the session is dropped again).
  Future<void> adminSignIn({required String email, required String password});

  /// True when the current session belongs to a staff member. Answered by the
  /// database: RLS returns the caller's `admins` row only if they are one.
  Future<bool> isCurrentUserAdmin();

  /// Every confirmed appointment whose day falls between [from] and [to]
  /// (inclusive), across all customers, soonest first. Past and future days
  /// alike — the admin calendar shows any day. Returns rows only for a staff
  /// caller (admin RLS policy).
  Future<List<Appointment>> fetchAppointmentsInRange(DateTime from, DateTime to);

  /// Cancels any customer's appointment, releasing its slot. Staff-only.
  Future<void> adminCancel(String appointmentId);

  /// Ends the staff session.
  Future<void> adminSignOut();
}
