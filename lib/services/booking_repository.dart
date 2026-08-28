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
}
