import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/profile.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/services/booking_exception.dart';
import 'package:minerva_app/services/booking_repository.dart';

/// In-memory stand-in for Supabase.
///
/// It reproduces the one behaviour the real schema guarantees and that the app
/// depends on: a slot can hold at most one confirmed booking, and the second
/// attempt loses with [SlotTakenException] — the same way the partial unique
/// index behaves. That makes the race testable without a live database.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({this.userId = 'user-1'});

  final String userId;

  /// Every booking, from every user.
  final List<Appointment> appointments = [];
  Profile? profile;

  bool signedIn = false;
  int bookCallCount = 0;

  /// Set to make the next call of each kind fail, for testing error paths.
  BookingException? failOnLoad;
  BookingException? failOnBook;
  BookingException? failOnAvailability;

  /// Runs just before an insert is committed. Lets a test slip another
  /// booking in at exactly the wrong moment.
  Future<void> Function()? onBeforeBook;

  int _nextId = 1;

  @override
  String? get currentUserId => signedIn ? userId : null;

  @override
  Future<void> ensureSignedIn() async => signedIn = true;

  @override
  Future<List<Appointment>> fetchMyAppointments() async {
    final failure = failOnLoad;
    if (failure != null) throw failure;
    return appointments.where((a) => a.userId == userId).toList();
  }

  @override
  Future<Set<Slot>> fetchBookedSlots(DateTime from, DateTime to) async {
    final failure = failOnAvailability;
    if (failure != null) throw failure;

    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);

    return appointments
        .where((a) => !a.isCancelled)
        .map((a) => a.slot)
        .where((s) => !s.date.isBefore(fromDay) && !s.date.isAfter(toDay))
        .toSet();
  }

  @override
  Future<Appointment> book({
    required Slot slot,
    required String firstName,
    required String lastName,
    required String phone,
    String? serviceId,
  }) async {
    bookCallCount++;

    final failure = failOnBook;
    if (failure != null) throw failure;

    await onBeforeBook?.call();

    // The unique index, in miniature.
    final taken = appointments.any((a) => !a.isCancelled && a.slot == slot);
    if (taken) throw const SlotTakenException();

    final appointment = Appointment(
      id: 'appt-${_nextId++}',
      userId: userId,
      slot: slot,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      serviceId: serviceId,
      createdAt: DateTime.now(),
    );

    appointments.add(appointment);
    return appointment;
  }

  @override
  Future<void> cancel(String appointmentId) async {
    final index = appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;
    appointments[index] =
        appointments[index].copyWith(status: AppointmentStatus.cancelled);
  }

  @override
  Future<Profile?> fetchProfile() async {
    final failure = failOnLoad;
    if (failure != null) throw failure;
    return profile;
  }

  @override
  Future<Profile> saveProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    profile = Profile(
      id: userId,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      updatedAt: DateTime.now(),
    );
    return profile!;
  }

  /// Books as a different customer — used to occupy a slot from "outside".
  Appointment bookAsSomeoneElse(Slot slot, {String otherUserId = 'user-2'}) {
    final appointment = Appointment(
      id: 'appt-${_nextId++}',
      userId: otherUserId,
      slot: slot,
      firstName: 'Other',
      lastName: 'Customer',
      phone: '5559998877',
    );
    appointments.add(appointment);
    return appointment;
  }
}
