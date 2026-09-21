import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/customer.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/providers/appointment_provider.dart';
import 'package:minerva_app/providers/availability_provider.dart';
import 'package:minerva_app/services/booking_exception.dart';

import 'fake_booking_repository.dart';

/// The behaviour the whole Supabase change exists to guarantee: two people
/// cannot end up holding the same slot.
///
/// The real guard is the partial unique index in
/// `supabase/migrations/…_init.sql`; these tests pin the *app's* half of the
/// contract — that it never tries to decide availability for itself, and that
/// losing the race is handled as a normal outcome rather than a crash.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Relative to the clock, never a fixed date: some of the tests below assert
  // the booking lands in `upcoming`, which filters on DateTime.now(), so a
  // hard-coded day silently starts failing once that day passes.
  final slot = Slot(DateTime.now().add(const Duration(days: 7)), 14);

  Future<AppointmentProvider> providerFor(FakeBookingRepository repo) async {
    final provider = AppointmentProvider(repo);
    await provider.load();
    return provider;
  }

  group('Double booking', () {
    test('the second booking of the same slot is rejected', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      expect(
        () => provider.book(
          slot: slot,
          firstName: 'Elif',
          lastName: 'Yilmaz',
          phone: '5557654321',
        ),
        throwsA(isA<SlotTakenException>()),
      );

      expect(repo.appointments.where((a) => !a.isCancelled).length, 1);
    });

    test('a slot taken by another customer cannot be booked', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      repo.bookAsSomeoneElse(slot);

      expect(
        () => provider.book(
          slot: slot,
          firstName: 'Ayse',
          lastName: 'Celik',
          phone: '5551234567',
        ),
        throwsA(isA<SlotTakenException>()),
      );
    });

    test(
      'a slot that falls free between check and insert still cannot double book',
      () async {
        // The dangerous interleaving: availability said "free", and someone
        // else commits before this insert lands. The app must not have cached
        // that answer as permission to write.
        final repo = FakeBookingRepository();
        final provider = await providerFor(repo);

        final free = await repo.fetchBookedSlots(slot.date, slot.date);
        expect(free.contains(slot), isFalse, reason: 'slot starts free');

        // Someone else books in the gap.
        repo.onBeforeBook = () async {
          repo.onBeforeBook = null;
          repo.bookAsSomeoneElse(slot);
        };

        expect(
          () => provider.book(
            slot: slot,
            firstName: 'Ayse',
            lastName: 'Celik',
            phone: '5551234567',
          ),
          throwsA(isA<SlotTakenException>()),
        );
      },
    );

    test('cancelling releases the slot for someone else', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      final mine = await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      await provider.cancel(mine.id);

      // The slot is free again, both to the availability query and to a write.
      final booked = await repo.fetchBookedSlots(slot.date, slot.date);
      expect(booked.contains(slot), isFalse);

      final theirs = repo.bookAsSomeoneElse(slot);
      expect(theirs.slot, slot);
    });

    test('a different hour on the same day is unaffected', () async {
      // The guarantee is per slot, not per day: one customer at 14:00 must not
      // stop a different customer taking 16:00. (The same customer could not —
      // that is the booking window's job, tested below.)
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      final other = repo.bookAsSomeoneElse(Slot(slot.date, 16));

      expect(other.slot.hour, 16);
      expect(repo.appointments.length, 2);
    });
  });

  group('One visit per three weeks', () {
    // The rule the database enforces as MN002. The fake mirrors it, so the
    // app's half of the contract — surfacing it as an explainable outcome
    // rather than a crash — can be tested without a live database.

    Future<Appointment> bookAt(AppointmentProvider provider, Slot at) =>
        provider.book(
          slot: at,
          firstName: 'Ayse',
          lastName: 'Celik',
          phone: '5551234567',
        );

    test('a second booking inside the window is refused', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      await bookAt(provider, slot);

      expect(
        () => bookAt(provider, Slot(slot.date.add(const Duration(days: 7)), 10)),
        throwsA(isA<BookingWindowException>()),
      );
    });

    test('it applies backwards too, not only forwards', () async {
      // Booking an *earlier* day after a later one would otherwise slip
      // through a rule written as "21 days after".
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      await bookAt(provider, Slot(slot.date.add(const Duration(days: 10)), 10));

      expect(
        () => bookAt(provider, slot),
        throwsA(isA<BookingWindowException>()),
      );
    });

    test('exactly 21 days apart is allowed', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      await bookAt(provider, slot);
      final second = await bookAt(
        provider,
        Slot(slot.date.add(const Duration(days: 21)), 10),
      );

      expect(second.slot.date, slot.date.add(const Duration(days: 21)));
    });

    test('the refusal names the day that is in the way', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      await bookAt(provider, slot);

      try {
        await bookAt(provider, Slot(slot.date.add(const Duration(days: 3)), 10));
        fail('expected the window to refuse this');
      } on BookingWindowException catch (failure) {
        // Without this the customer is told "not yet" and nothing else.
        expect(failure.existingDate, slot.date);
        expect(failure.nextAvailable, slot.date.add(const Duration(days: 21)));
      }
    });

    test('a cancelled booking stops holding the window', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      final first = await bookAt(provider, slot);
      await provider.cancel(first.id);

      final second = await bookAt(
        provider,
        Slot(slot.date.add(const Duration(days: 2)), 10),
      );
      expect(second.id, isNotEmpty);
    });

    test('a no-show releases the customer as well', () async {
      // Marking somebody a no-show is not only a label for the statistics
      // page: it is what lets them book again, because they received nothing.
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      final first = await bookAt(provider, slot);

      await repo.adminSignIn(
        email: repo.validAdminEmail,
        password: repo.validAdminPassword,
      );
      await repo.adminSetStatus(first.id, AppointmentStatus.noShow);
      await repo.adminSignOut();

      final second = await bookAt(
        provider,
        Slot(slot.date.add(const Duration(days: 2)), 10),
      );
      expect(second.id, isNotEmpty);
    });
  });

  group('Slot identity', () {
    test('a slot is a wall-clock date and hour, not an instant', () {
      // Two DateTimes describing the same calendar day compare equal as slots
      // whatever time component they carry, so the key cannot drift.
      final a = Slot(DateTime(2026, 9, 4, 23, 59), 14);
      final b = Slot(DateTime(2026, 9, 4), 14);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.dateKey, '2026-09-04');
    });

    test('different days or hours are different slots', () {
      expect(Slot(DateTime(2026, 9, 4), 14) == Slot(DateTime(2026, 9, 5), 14),
          isFalse);
      expect(Slot(DateTime(2026, 9, 4), 14) == Slot(DateTime(2026, 9, 4), 16),
          isFalse);
    });

    test('dateKey is zero padded for Postgres', () {
      expect(Slot(DateTime(2026, 1, 2), 10).dateKey, '2026-01-02');
    });

    test('round trips through the database representation', () {
      final original = Slot(DateTime(2026, 9, 4), 14);
      final restored = Slot(Slot.parseDate(original.dateKey), original.hour);
      expect(restored, original);
    });
  });

  group('Availability', () {
    test('reports slots taken by anyone, not just this user', () async {
      final repo = FakeBookingRepository();
      final availability = AvailabilityProvider(repo);

      repo.bookAsSomeoneElse(slot);
      await availability.loadFor(slot.date);

      expect(availability.isTaken(slot), isTrue);
      expect(availability.isTaken(Slot(slot.date, 16)), isFalse);
    });

    test('a failed lookup reports itself rather than claiming all free',
        () async {
      final repo = FakeBookingRepository()
        ..failOnAvailability = const BookingOfflineException();
      final availability = AvailabilityProvider(repo);

      await availability.loadFor(slot.date);

      expect(availability.isUnverified, isTrue);
      expect(availability.error, isA<BookingOfflineException>());
    });

    test('markTaken updates the grid without a round trip', () async {
      final repo = FakeBookingRepository();
      final availability = AvailabilityProvider(repo);
      await availability.loadFor(slot.date);

      expect(availability.isTaken(slot), isFalse);
      availability.markTaken(slot);
      expect(availability.isTaken(slot), isTrue);
    });

    test('cancelled bookings do not occupy a slot', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);
      final availability = AvailabilityProvider(repo);

      final mine = await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );
      await provider.cancel(mine.id);

      await availability.loadFor(slot.date);
      expect(availability.isTaken(slot), isFalse);
    });
  });

  group('Customers', () {
    test('the first booking turns a visitor into a customer', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      expect(provider.customer, isNull, reason: 'nobody has booked yet');

      await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      expect(provider.customer?.displayName, 'Ayse Celik');
      expect(provider.customer?.phone, '5551234567');
      // The identity is the person, not the device that created them.
      expect(provider.customer?.id, repo.linkedCustomerId);
    });

    test('a later booking updates the saved details', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);

      await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );
      await provider.book(
        slot: Slot(slot.date, 16),
        firstName: 'Ayse',
        lastName: 'Yilmaz',
        phone: '5559998877',
      );

      expect(provider.customer?.lastName, 'Yilmaz');
      expect(provider.customer?.phone, '5559998877');
    });

    test('the booking still stands if saving the profile fails', () async {
      final repo = _ProfileFailingRepository();
      final provider = AppointmentProvider(repo);
      await provider.load();

      final appointment = await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      expect(appointment.id, isNotEmpty);
      expect(provider.upcoming.length, 1);
      expect(provider.customer, isNull);
    });
  });

  group('Loading and offline', () {
    test('opening the app signs in nobody and writes nothing', () async {
      // The database must only ever hold people who actually did something.
      // Browsing the salon's availability is not doing something, so a launch
      // that ends without a booking leaves no auth.users row behind.
      final repo = FakeBookingRepository();
      expect(repo.signedIn, isFalse);

      final provider = await providerFor(repo);

      expect(repo.signedIn, isFalse);
      expect(provider.upcoming, isEmpty);
      expect(provider.customer, isNull);
    });

    test('the first booking is what creates the identity', () async {
      final repo = FakeBookingRepository();
      final provider = await providerFor(repo);
      expect(repo.signedIn, isFalse);

      await provider.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      expect(repo.signedIn, isTrue);
    });


    test('falls back to the cache when the network is down', () async {
      final repo = FakeBookingRepository();
      final first = await providerFor(repo);

      await first.book(
        slot: slot,
        firstName: 'Ayse',
        lastName: 'Celik',
        phone: '5551234567',
      );

      // A fresh provider that cannot reach the server still shows the booking.
      final offlineRepo = FakeBookingRepository()
        ..failOnLoad = const BookingOfflineException();
      final second = AppointmentProvider(offlineRepo);
      await second.load();

      expect(second.upcoming.length, 1);
      expect(second.isStale, isTrue, reason: 'must admit the data is cached');
      expect(second.state, LoadState.ready);
    });

    test('reports failure when there is no cache to fall back on', () async {
      final repo = FakeBookingRepository()
        ..failOnLoad = const BookingOfflineException();
      final provider = AppointmentProvider(repo);

      await provider.load();

      expect(provider.state, LoadState.failed);
      expect(provider.error, isA<BookingOfflineException>());
      expect(provider.appointments, isEmpty);
    });
  });
}

/// Books fine, but never manages to read the customer back afterwards.
class _ProfileFailingRepository extends FakeBookingRepository {
  @override
  Future<Customer?> currentCustomer() async {
    throw const BookingFailedException('customer read failed');
  }
}
