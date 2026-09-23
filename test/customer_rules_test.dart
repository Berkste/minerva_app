import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/providers/appointment_provider.dart';
import 'package:minerva_app/providers/availability_provider.dart';
import 'package:minerva_app/providers/booking_provider.dart';
import 'package:minerva_app/services/booking_exception.dart';

import 'fake_booking_repository.dart';

/// What the customer screens promise, checked at the layer that decides it.
///
/// Each of these mirrors a rule the database enforces. The point is not to
/// re-test the database — it is that the app must reach the same conclusion
/// *before* asking, so a customer is shown what is possible rather than being
/// refused after three taps.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The next given weekday strictly after today, so tests never sit on a
  /// boundary that today happens to be.
  DateTime nextWeekday(int weekday) {
    var day = DateTime.now().add(const Duration(days: 1));
    day = DateTime(day.year, day.month, day.day);
    while (day.weekday != weekday) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  group('What the calendar may offer', () {
    test('Sunday is closed before anything has loaded', () async {
      // A standing rule, not data: the grid must not need a round trip to know
      // the salon is shut on Sundays.
      final availability = AvailabilityProvider(FakeBookingRepository());

      expect(
        availability.availabilityOf(nextWeekday(DateTime.sunday)),
        DayAvailability.closed,
      );
    });

    test('a declared holiday closes its days', () async {
      final repo = FakeBookingRepository();
      await repo.adminSignIn(
        email: repo.validAdminEmail,
        password: repo.validAdminPassword,
      );

      final from = nextWeekday(DateTime.monday);
      final to = from.add(const Duration(days: 3));
      await repo.addClosure(from: from, to: to, reason: 'Tatil');

      final availability = AvailabilityProvider(repo);

      // The calendar loads the month it is showing, so a closure that runs
      // across a month boundary is answered by two loads — exactly as it
      // would be when somebody pages from September into October.
      Future<DayAvailability> stateOf(DateTime day) async {
        await availability.loadMonth(day, force: true);
        return availability.availabilityOf(day);
      }

      expect(await stateOf(from), DayAvailability.closed);
      expect(await stateOf(to), DayAvailability.closed);

      final after = to.add(const Duration(days: 1));
      expect(
        await stateOf(after),
        after.weekday == DateTime.sunday
            ? DayAvailability.closed
            : DayAvailability.open,
        reason: 'the day after the holiday is open again, unless it is a Sunday',
      );
    });

    test('a day is full only when every hour is gone', () async {
      final repo = FakeBookingRepository();
      final day = nextWeekday(DateTime.tuesday);

      // All but one.
      for (final hour in Slot.salonHours.take(Slot.salonHours.length - 1)) {
        repo.bookAsSomeoneElse(Slot(day, hour), phone: '555000000$hour');
      }

      final availability = AvailabilityProvider(repo);
      await availability.loadMonth(day);
      expect(availability.availabilityOf(day), DayAvailability.open);

      repo.bookAsSomeoneElse(Slot(day, Slot.salonHours.last), phone: '5559990000');
      await availability.loadMonth(day, force: true);

      expect(availability.availabilityOf(day), DayAvailability.full);
    });

    test('a cancelled booking frees the day again', () async {
      final repo = FakeBookingRepository();
      final day = nextWeekday(DateTime.wednesday);

      final booked = [
        for (final hour in Slot.salonHours)
          repo.bookAsSomeoneElse(Slot(day, hour), phone: '555111000$hour'),
      ];

      final availability = AvailabilityProvider(repo);
      await availability.loadMonth(day);
      expect(availability.availabilityOf(day), DayAvailability.full);

      await repo.adminSignIn(
        email: repo.validAdminEmail,
        password: repo.validAdminPassword,
      );
      await repo.adminSetStatus(booked.first.id, AppointmentStatus.cancelled);
      await availability.loadMonth(day, force: true);

      expect(availability.availabilityOf(day), DayAvailability.open);
    });

    test('a month that will not load leaves days offerable', () async {
      // Better to let someone pick a day the database then refuses than to
      // grey out the whole calendar because the network hiccuped.
      final repo = FakeBookingRepository()
        ..failOnAvailability = const BookingOfflineException();
      final availability = AvailabilityProvider(repo);

      await availability.loadMonth(nextWeekday(DateTime.thursday));

      expect(availability.isMonthUnverified, isTrue);
      expect(
        availability.availabilityOf(nextWeekday(DateTime.thursday)),
        DayAvailability.open,
      );
    });
  });

  group('What the customer may still change', () {
    Appointment at(DateTime start, {bool byAdmin = false}) => Appointment(
          id: 'a1',
          customerId: 'cust-1',
          slot: Slot(start, start.hour),
          firstName: 'Ayse',
          phone: '5551234567',
          createdByAdmin: byAdmin,
        );

    test('cancelling is offered up to an hour before', () {
      final now = DateTime(2026, 10, 5, 9);
      final appointment = at(DateTime(2026, 10, 5, 12));

      expect(appointment.canBeCancelledByCustomer(now: now), isTrue);
    });

    test('and withdrawn inside that hour', () {
      // Mirrors MN004. The button disappears rather than failing when pressed.
      final now = DateTime(2026, 10, 5, 11, 30);
      final appointment = at(DateTime(2026, 10, 5, 12));

      expect(appointment.canBeCancelledByCustomer(now: now), isFalse);
    });

    test('a booking the salon entered is not the device\'s to change', () {
      // Whoever typed that phone number into the app did not necessarily make
      // this booking, so it is changed by calling the salon.
      final now = DateTime(2026, 10, 5, 9);
      final appointment = at(DateTime(2026, 10, 5, 12), byAdmin: true);

      expect(appointment.canBeCancelledByCustomer(now: now), isFalse);
      expect(appointment.canBeChangedByCustomer(now: now), isFalse);
    });

    test('a cancelled booking offers nothing', () {
      final now = DateTime(2026, 10, 5, 9);
      final appointment = at(DateTime(2026, 10, 5, 12))
          .copyWith(status: AppointmentStatus.cancelled);

      expect(appointment.canBeCancelledByCustomer(now: now), isFalse);
    });
  });

  group('Moving a booking', () {
    test('keeps the customer and takes the new slot', () async {
      final repo = FakeBookingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      final day = nextWeekday(DateTime.thursday);
      final booked = await provider.book(
        slot: Slot(day, 10),
        firstName: 'Ayse',
        phone: '5551234567',
      );

      final moved = await provider.reschedule(booked.id, Slot(day, 16));

      expect(moved.id, booked.id);
      expect(moved.customerId, booked.customerId);
      expect(moved.slot.hour, 16);
      expect(repo.appointments.length, 1, reason: 'moved, not duplicated');
    });

    test('is refused when the new slot is taken', () async {
      final repo = FakeBookingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      final day = nextWeekday(DateTime.thursday);
      final booked = await provider.book(
        slot: Slot(day, 10),
        firstName: 'Ayse',
        phone: '5551234567',
      );
      repo.bookAsSomeoneElse(Slot(day, 16));

      expect(
        () => provider.reschedule(booked.id, Slot(day, 16)),
        throwsA(isA<SlotTakenException>()),
      );
    });

    test('is refused into a closed day', () async {
      final repo = FakeBookingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      final booked = await provider.book(
        slot: Slot(nextWeekday(DateTime.thursday), 10),
        firstName: 'Ayse',
        phone: '5551234567',
      );

      expect(
        () => provider.reschedule(
          booked.id,
          Slot(nextWeekday(DateTime.sunday), 10),
        ),
        throwsA(isA<SalonClosedException>()),
      );
    });

    test('does not trip over its own booking window', () async {
      // The row being moved must be excluded from its own 21-day check, or
      // nobody could ever move an appointment by a day.
      final repo = FakeBookingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      final day = nextWeekday(DateTime.thursday);
      final booked = await provider.book(
        slot: Slot(day, 10),
        firstName: 'Ayse',
        phone: '5551234567',
      );

      final moved = await provider.reschedule(
        booked.id,
        Slot(day.add(const Duration(days: 1)), 10),
      );

      expect(moved.slot.date, day.add(const Duration(days: 1)));
    });

    test('the draft carries the booking being moved', () {
      // What puts the calendar into "move this one" mode rather than
      // "start a new one".
      final day = nextWeekday(DateTime.friday);
      final appointment = Appointment(
        id: 'a1',
        customerId: 'cust-1',
        slot: Slot(day, 14),
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      final booking = BookingProvider()..beginReschedule(appointment);

      expect(booking.isRescheduling, isTrue);
      expect(booking.reschedulingId, 'a1');
      expect(booking.date, day);
      expect(booking.hour, 14);
      expect(booking.phone, '5551234567');

      booking.reset();
      expect(booking.isRescheduling, isFalse);
    });
  });

  group('The customer\'s own details', () {
    test('saving them before any booking creates the person', () async {
      final repo = FakeBookingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      expect(provider.customer, isNull);

      final saved = await provider.saveCustomer(
        firstName: 'Ayse',
        phone: '5551234567',
      );

      expect(saved.firstName, 'Ayse');
      expect(provider.customer?.id, saved.id);
      expect(repo.customers.single.phone, '5551234567');
    });

    test('a surname is optional and stays absent rather than blank', () async {
      final repo = FakeBookingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      final saved = await provider.saveCustomer(
        firstName: 'Ayse',
        lastName: '   ',
        phone: '5551234567',
      );

      expect(saved.lastName, isNull);
      expect(saved.displayName, 'Ayse');
    });

    test('editing does not rewrite what past bookings recorded', () async {
      // The booking keeps who booked it; the customer record is who they are
      // now. Conflating the two would rewrite history every time somebody
      // changed their number.
      final repo = FakeBookingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      final booked = await provider.book(
        slot: Slot(nextWeekday(DateTime.thursday), 10),
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      await provider.saveCustomer(
        firstName: 'Ayse',
        lastName: 'Yilmaz',
        phone: '5551234567',
      );

      expect(repo.appointments.single.id, booked.id);
      expect(repo.appointments.single.lastName, 'Celik');
      expect(provider.customer?.lastName, 'Yilmaz');
    });

    test('claiming a number under the wrong name is refused', () async {
      // The only thing standing between a phone number and the record behind
      // it. Friction, not security — but it has to actually be there.
      final repo = FakeBookingRepository();
      await repo.claimCustomer(firstName: 'Ayse', phone: '5551234567');

      expect(
        () => repo.claimCustomer(firstName: 'Mehmet', phone: '5551234567'),
        throwsA(isA<NameDoesNotMatchException>()),
      );
    });

    test('…and accepted when the name matches, case aside', () async {
      final repo = FakeBookingRepository();
      final first = await repo.claimCustomer(
        firstName: 'Ayse',
        phone: '5551234567',
      );

      final again = await repo.claimCustomer(
        firstName: '  ayse ',
        phone: '5551234567',
      );

      expect(again.id, first.id, reason: 'the same person, not a second one');
      expect(repo.customers.length, 1);
    });
  });
}
