import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/salon_service.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/providers/appointment_provider.dart';
import 'package:minerva_app/services/booking_exception.dart';

import 'fake_booking_repository.dart';

/// What staff can do that customers cannot, and what it costs them.
///
/// The admin app's whole reason to exist is the exemptions: the salon knows
/// things the rules cannot, so staff book on closed days, inside the window,
/// and after the cancellation deadline. Each of those is only safe because it
/// is deliberate, so each is checked here.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A day the salon is open, far enough out to be bookable.
  DateTime openDay(int daysFromNow) {
    var day = DateTime.now().add(Duration(days: daysFromNow));
    day = DateTime(day.year, day.month, day.day);
    return day.weekday == DateTime.sunday
        ? day.add(const Duration(days: 1))
        : day;
  }

  DateTime nextSunday() {
    var day = DateTime.now().add(const Duration(days: 1));
    day = DateTime(day.year, day.month, day.day);
    while (day.weekday != DateTime.sunday) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  Future<FakeBookingRepository> signedInSalon() async {
    final repo = FakeBookingRepository();
    await repo.adminSignIn(
      email: repo.validAdminEmail,
      password: repo.validAdminPassword,
    );
    return repo;
  }

  group('Booking on somebody\'s behalf', () {
    test('a new number creates the person', () async {
      final repo = await signedInSalon();

      await repo.adminBook(
        slot: Slot(openDay(3), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      expect(repo.customers.single.firstName, 'Zeynep');
      expect(repo.customers.single.createdByAdmin, isTrue);
    });

    test('a number the salon already knows attaches to that person', () async {
      // The whole point of keying customers by phone: the walk-in the salon
      // typed in last month is the same person who installs the app today.
      final repo = await signedInSalon();
      await repo.claimCustomer(firstName: 'Zeynep', phone: '5551110000');

      await repo.adminBook(
        slot: Slot(openDay(3), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      expect(repo.customers.length, 1);
      expect(repo.appointments.single.customerId, repo.customers.single.id);
    });

    test('staff are exempt from the three-week window', () async {
      final repo = await signedInSalon();
      final day = openDay(3);

      await repo.adminBook(
        slot: Slot(day, 10),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      // Two days later, for the same person. A customer could not.
      await repo.adminBook(
        slot: Slot(openDay(5), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      expect(repo.appointments.length, 2);
    });

    test('and from closed days', () async {
      final repo = await signedInSalon();

      await repo.adminBook(
        slot: Slot(nextSunday(), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      expect(repo.appointments.single.slot.date.weekday, DateTime.sunday);
    });

    test('but not from the slot already being taken', () async {
      // The one guarantee nobody is exempt from. Two people in one chair is
      // not a policy decision.
      final repo = await signedInSalon();
      final slot = Slot(openDay(3), 12);
      repo.bookAsSomeoneElse(slot);

      expect(
        () => repo.adminBook(
          slot: slot,
          firstName: 'Zeynep',
          phone: '5551110000',
        ),
        throwsA(isA<SlotTakenException>()),
      );
    });

    test('a booking the salon made is marked as such', () async {
      // Which is what stops the customer's app from changing it later.
      final repo = await signedInSalon();

      final booked = await repo.adminBook(
        slot: Slot(openDay(3), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      expect(booked.createdByAdmin, isTrue);
      expect(booked.canBeCancelledByCustomer(), isFalse);
    });
  });

  group('Recording what was done', () {
    Future<(FakeBookingRepository, Appointment)> salonWithBooking() async {
      final repo = await signedInSalon();
      final booked = await repo.adminBook(
        slot: Slot(openDay(3), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );
      return (repo, booked);
    }

    test('a line item adds its amount to the total', () async {
      final (repo, booked) = await salonWithBooking();

      await repo.addLineItem(
        appointmentId: booked.id,
        serviceId: 'medikal_manikur',
      );

      expect(repo.appointments.single.total, 450);
    });

    test('an amount given overrides the catalogue', () async {
      // Two add-ons are priced as a range, so only the salon knows what a
      // visit came to. The catalogue is a default, not the truth.
      final (repo, booked) = await salonWithBooking();

      await repo.addLineItem(
        appointmentId: booked.id,
        serviceId: 'medikal_manikur',
        amount: 380,
      );

      expect(repo.appointments.single.total, 380);
    });

    test('taking a line off takes its amount with it', () async {
      final (repo, booked) = await salonWithBooking();

      await repo.addLineItem(
        appointmentId: booked.id,
        serviceId: 'medikal_manikur',
      );
      await repo.addLineItem(
        appointmentId: booked.id,
        serviceId: 'protez_tirnak',
      );
      expect(repo.appointments.single.total, 1450);

      final line = repo.appointments.single.services.first;
      await repo.removeLineItem(line.id!);

      expect(repo.appointments.single.total, 1000);
    });

    test('changing a price does not rewrite what a past visit cost', () async {
      // The amount is copied onto the line when it is added. Editing the menu
      // is a decision about the future.
      final (repo, booked) = await salonWithBooking();
      await repo.addLineItem(
        appointmentId: booked.id,
        serviceId: 'medikal_manikur',
      );

      await repo.saveService(
        const SalonService(
          id: 'medikal_manikur',
          kind: ServiceKind.main,
          nameTr: 'Medikal Manikür',
          nameEn: 'Medical Manicure',
          priceMin: 600,
        ),
      );

      expect(repo.appointments.single.total, 450);
    });
  });

  group('Saying how it went', () {
    test('marking a booking done leaves it holding its slot', () async {
      // A completed visit still occupied that chair; freeing the slot would
      // let somebody book a time that has already happened.
      final repo = await signedInSalon();
      final slot = Slot(openDay(3), 12);
      final booked = await repo.adminBook(
        slot: slot,
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      await repo.adminSetStatus(booked.id, AppointmentStatus.completed);

      expect(await repo.fetchBookedSlots(slot.date, slot.date), contains(slot));
    });

    test('marking a no-show frees the slot', () async {
      final repo = await signedInSalon();
      final slot = Slot(openDay(3), 12);
      final booked = await repo.adminBook(
        slot: slot,
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      await repo.adminSetStatus(booked.id, AppointmentStatus.noShow);

      expect(
        await repo.fetchBookedSlots(slot.date, slot.date),
        isNot(contains(slot)),
      );
    });

    test('staff may cancel inside the hour a customer cannot', () async {
      // The salon is the one who knows the chair is free.
      final repo = await signedInSalon();
      final now = DateTime.now();
      final soon = Slot(DateTime(now.year, now.month, now.day), now.hour);

      final booked = Appointment(
        id: 'a1',
        customerId: 'cust-1',
        slot: soon,
        firstName: 'Zeynep',
        phone: '5551110000',
      );
      repo.appointments.add(booked);

      await repo.cancel(booked.id);

      expect(repo.appointments.single.status, AppointmentStatus.cancelled);
    });
  });

  group('The customer list', () {
    test('searches by name or by number', () async {
      final repo = await signedInSalon();
      await repo.claimCustomer(firstName: 'Zeynep', phone: '5551110000');
      await repo.claimCustomer(firstName: 'Ayse', phone: '5552220000');

      expect((await repo.fetchCustomers(query: 'zey')).single.firstName, 'Zeynep');
      expect((await repo.fetchCustomers(query: '5552')).single.firstName, 'Ayse');
      expect((await repo.fetchCustomers()).length, 2);
    });

    test('archiving hides somebody without unmaking them', () async {
      // Nothing is ever really deleted; their bookings are still the salon's
      // record of what happened.
      final repo = await signedInSalon();
      final customer =
          await repo.claimCustomer(firstName: 'Zeynep', phone: '5551110000');
      await repo.adminBook(
        slot: Slot(openDay(3), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      await repo.setCustomerArchived(customer.id, true);

      expect(await repo.fetchCustomers(), isEmpty);
      expect(
        (await repo.fetchCustomers(includeArchived: true)).single.id,
        customer.id,
      );
      expect(repo.appointments, hasLength(1));
    });

    test('and restoring brings them back', () async {
      final repo = await signedInSalon();
      final customer =
          await repo.claimCustomer(firstName: 'Zeynep', phone: '5551110000');

      await repo.setCustomerArchived(customer.id, true);
      await repo.setCustomerArchived(customer.id, false);

      expect((await repo.fetchCustomers()).single.id, customer.id);
    });

    test('a correction reaches the record but not the bookings', () async {
      final repo = await signedInSalon();
      final customer =
          await repo.claimCustomer(firstName: 'Zeynep', phone: '5551110000');
      await repo.adminBook(
        slot: Slot(openDay(3), 12),
        firstName: 'Zeynep',
        phone: '5551110000',
      );

      await repo.adminUpdateCustomer(
        customerId: customer.id,
        firstName: 'Zeynep',
        lastName: 'Kaya',
        phone: '5551110000',
      );

      expect(repo.customers.single.lastName, 'Kaya');
      expect(repo.appointments.single.lastName, isNull);
    });
  });

  group('Closing the salon', () {
    test('a declared closure stops customers booking those days', () async {
      final repo = await signedInSalon();
      final day = openDay(4);
      await repo.addClosure(from: day, to: day, reason: 'Tatil');
      await repo.adminSignOut();

      final provider = AppointmentProvider(repo);
      await provider.load();

      expect(
        () => provider.book(
          slot: Slot(day, 12),
          firstName: 'Ayse',
          phone: '5551234567',
        ),
        throwsA(isA<SalonClosedException>()),
      );
    });

    test('and removing it opens them again', () async {
      final repo = await signedInSalon();
      final day = openDay(4);
      final closure = await repo.addClosure(from: day, to: day);

      await repo.removeClosure(closure.id);
      await repo.adminSignOut();

      final provider = AppointmentProvider(repo);
      await provider.load();

      final booked = await provider.book(
        slot: Slot(day, 12),
        firstName: 'Ayse',
        phone: '5551234567',
      );
      expect(booked.slot.date, day);
    });

    test('only staff may declare one', () async {
      final repo = FakeBookingRepository();

      expect(
        () => repo.addClosure(from: openDay(4), to: openDay(4)),
        throwsA(isA<NotAnAdminException>()),
      );
    });
  });
}
