import '../models/appointment.dart';
import '../models/customer.dart';
import '../models/salon_closure.dart';
import '../models/salon_service.dart';
import '../models/slot.dart';

/// Everything the app needs from the backend.
///
/// An interface rather than a concrete class so the whole booking flow can be
/// driven by an in-memory fake in tests — including the double-booking race
/// and the 21-day window, both of which are otherwise awkward to reproduce.
abstract interface class BookingRepository {
  /// Id of the signed-in device session, or null before sign-in.
  ///
  /// A session is a device, not a person. [currentCustomer] is the person.
  String? get currentUserId;

  /// Signs in anonymously if there is no session yet. Safe to call repeatedly.
  ///
  /// Deliberately not called at launch: opening the app must not write
  /// anything. An identity appears when somebody books.
  Future<void> ensureSignedIn();

  // --- the person ----------------------------------------------------------

  /// The customer this device is linked to, or null if it never booked.
  Future<Customer?> currentCustomer();

  /// Finds the person behind [phone], or creates them, and links this device.
  ///
  /// Throws [NameDoesNotMatchException] when a record exists for that number
  /// under a different first name — the only check standing between a phone
  /// number and the record behind it.
  Future<Customer> claimCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  });

  /// Updates this device's own customer record.
  Future<Customer> updateCustomer({
    required String firstName,
    String? lastName,
    required String phone,
  });

  // --- browsing ------------------------------------------------------------

  /// Slots already taken between [from] and [to], inclusive.
  ///
  /// Returns slot keys for *everyone's* bookings — that is the point, so the
  /// grid can grey out unavailable times — but never any customer details.
  /// Works without a session, so the calendar loads before anyone identifies
  /// themselves.
  Future<Set<Slot>> fetchBookedSlots(DateTime from, DateTime to);

  /// Days the salon is shut in that range: every Sunday, plus any declared
  /// closure. Works without a session, for the same reason.
  Future<Set<DateTime>> fetchClosedDays(DateTime from, DateTime to);

  /// The treatments a customer can book, in the salon's own order.
  Future<List<SalonService>> fetchTreatments();

  // --- this device's bookings ---------------------------------------------

  /// This customer's bookings, soonest first.
  ///
  /// A claimed record shows only future appointments unless this very device
  /// made them — which is what limits the damage when somebody types a phone
  /// number that is not theirs.
  Future<List<Appointment>> fetchMyAppointments();

  /// Books [slot], creating or claiming the customer in the same breath.
  ///
  /// One call, one transaction: identity, appointment and chosen treatment
  /// together or not at all.
  ///
  /// Throws [SlotTakenException] when somebody else got there first,
  /// [SlotInThePastException], [BookingWindowException], [SalonClosedException]
  /// or [NameDoesNotMatchException] as the rules apply.
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    String? lastName,
    required String phone,
    String? serviceId,
  });

  /// Moves an existing booking to a different slot.
  ///
  /// Subject to the same rules as making one, and refused for a booking the
  /// salon entered on the customer's behalf.
  Future<Appointment> reschedule(String appointmentId, Slot slot);

  /// Changes the treatment on an existing booking; null clears it.
  Future<void> setTreatment(String appointmentId, String? serviceId);

  /// Calls off a booking, which releases its slot.
  ///
  /// Throws [CancelTooLateException] within an hour of the start.
  Future<void> cancel(String appointmentId);

  // --- Admin / employee ----------------------------------------------------
  // These succeed only for a caller the database recognises as staff. The
  // authorization is enforced by RLS, not by the app; the methods here are
  // just how the admin screens reach it.

  /// Signs in a staff member with email + password and confirms they are
  /// actually an admin.
  Future<void> adminSignIn({required String email, required String password});

  /// True when the current session belongs to a staff member.
  Future<bool> isCurrentUserAdmin();

  /// Every booking whose day falls between [from] and [to] (inclusive), across
  /// all customers, soonest first. Staff only.
  Future<List<Appointment>> fetchAppointmentsInRange(DateTime from, DateTime to);

  /// Books on a customer's behalf, creating the person if that phone number is
  /// new. Exempt from the 21-day window and from closed days.
  Future<Appointment> adminBook({
    required Slot slot,
    required String firstName,
    String? lastName,
    required String phone,
    String? serviceId,
  });

  /// Sets any booking's status: cancelled, completed, or a no-show.
  ///
  /// Marking a no-show is not only a label — it releases that customer from
  /// the 21-day window, so the screen offering it should say so.
  Future<void> adminSetStatus(String appointmentId, AppointmentStatus status);

  /// The closures staff have declared that touch [from]..[to].
  ///
  /// Sundays are not among them: they are a standing rule, not a decision, and
  /// [fetchClosedDays] is what folds the two together for the calendar.
  Future<List<SalonClosure>> fetchClosures(DateTime from, DateTime to);

  /// Declares a closure. A single day off has [from] equal to [to].
  Future<SalonClosure> addClosure({
    required DateTime from,
    required DateTime to,
    String? reason,
  });

  /// Retires a closure, reopening those days.
  Future<void> removeClosure(String closureId);

  /// Every customer the salon knows, newest first.
  ///
  /// [query] matches a name or a phone number. Archived people are left out
  /// unless [includeArchived] is set — nothing is ever really deleted, so
  /// "deleted" is a filter rather than an absence.
  Future<List<Customer>> fetchCustomers({
    String? query,
    bool includeArchived = false,
  });

  /// Corrects a customer's details. Staff only.
  Future<Customer> adminUpdateCustomer({
    required String customerId,
    required String firstName,
    String? lastName,
    required String phone,
  });

  /// Archives a person, or brings them back. Their bookings stay either way.
  Future<void> setCustomerArchived(String customerId, bool archived);

  /// The whole catalogue — treatments and add-ons, active and retired.
  ///
  /// [fetchTreatments] is the customer's view; this is the one staff edit.
  Future<List<SalonService>> fetchCatalogue();

  /// Creates or updates a catalogue entry.
  Future<SalonService> saveService(SalonService service);

  /// Takes a service off the menu, or puts it back. Existing bookings that
  /// used it are unaffected — they recorded their own price.
  Future<void> setServiceActive(String serviceId, bool isActive);

  /// Records something the salon did on a booking, at the price it charged.
  ///
  /// [amount] defaults to the catalogue's lower bound, which is the whole
  /// point of it being a bound: two add-ons are priced by the work done.
  Future<void> addLineItem({
    required String appointmentId,
    required String serviceId,
    num? amount,
  });

  /// Takes a line off a booking. Soft, like everything else.
  Future<void> removeLineItem(String lineItemId);

  /// Ends the staff session.
  Future<void> adminSignOut();
}
