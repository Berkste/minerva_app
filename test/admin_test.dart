import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:minerva_app/admin/admin_app.dart';
import 'package:minerva_app/l10n/app_localizations.dart';
import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/providers/admin_provider.dart';
import 'package:minerva_app/providers/appointment_provider.dart' show LoadState;
import 'package:minerva_app/services/booking_exception.dart';
import 'package:minerva_app/services/booking_repository.dart';

import 'fake_booking_repository.dart';

/// The admin feature's contract: authenticating is not authorization, staff can
/// see and cancel everyone's bookings, and a non-admin can reach none of it.
/// Plus the calendar behaviour: it opens on today, a day's list is that day's
/// bookings, and days with bookings are marked.
///
/// The real boundary is the `is_admin()` RLS policy in the admin migration;
/// these tests pin the app's half — that it never treats a login as permission
/// and never reads the salon-wide list without the database allowing it.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  // Days inside the current month, so the default (today's month) load sees
  // them. `_dayHour` builds a slot on a given day-of-this-month at an hour.
  final now = DateTime.now();
  DateTime dayInThisMonth(int day) => DateTime(now.year, now.month, day);
  Slot slotOn(int day, int hour) => Slot(dayInThisMonth(day), hour);

  const email = 'admin@minerva.test';
  const password = 'correct-horse';

  Future<AdminProvider> signedInAdmin(FakeBookingRepository repo) async {
    final provider = AdminProvider(repo);
    await provider.signIn(email: email, password: password);
    return provider;
  }

  group('Admin authorization', () {
    test('wrong password is rejected', () async {
      final repo = FakeBookingRepository();
      final provider = AdminProvider(repo);

      final ok = await provider.signIn(email: email, password: 'WRONG');

      expect(ok, isFalse);
      expect(provider.auth, AdminAuthState.signedOut);
      expect(provider.authError, isA<InvalidAdminCredentialsException>());
    });

    test('valid credentials that are not staff are refused and signed out',
        () async {
      final repo = FakeBookingRepository()..credentialsAreAdmin = false;
      final provider = AdminProvider(repo);

      final ok = await provider.signIn(email: email, password: password);

      expect(ok, isFalse);
      expect(provider.auth, AdminAuthState.signedOut);
      expect(provider.authError, isA<NotAnAdminException>());
      expect(await repo.isCurrentUserAdmin(), isFalse);
    });

    test('a real staff login authenticates and loads the month', () async {
      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(now.day, 14), otherUserId: 'cust-A');
      final provider = await signedInAdmin(repo);

      expect(provider.auth, AdminAuthState.authenticated);
      expect(provider.listState, LoadState.ready);
    });
  });

  group('Admin data access', () {
    test('a non-admin caller reads none of the salon-wide list', () async {
      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(now.day, 14), otherUserId: 'cust-A');

      // No admin sign-in — mirrors RLS returning zero rows to a customer.
      final first = DateTime(now.year, now.month);
      final last = DateTime(now.year, now.month + 1, 0);
      expect(await repo.fetchAppointmentsInRange(first, last), isEmpty);
    });

    test('an admin sees every customer\'s appointment in the month', () async {
      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(now.day, 10), otherUserId: 'cust-A')
        ..bookAsSomeoneElse(slotOn(now.day, 12), otherUserId: 'cust-B');
      final provider = await signedInAdmin(repo);

      final owners = provider
          .appointmentsOn(dayInThisMonth(now.day))
          .map((a) => a.userId)
          .toSet();
      expect(owners, containsAll(<String>{'cust-A', 'cust-B'}));
    });

    test('a non-admin cannot cancel a booking they do not own', () async {
      final repo = FakeBookingRepository();
      final other = repo.bookAsSomeoneElse(slotOn(now.day, 14), otherUserId: 'cust-A');

      await repo.adminCancel(other.id); // no admin session

      expect(repo.appointments.single.status, AppointmentStatus.confirmed,
          reason: 'RLS would refuse; the fake refuses too');
    });

    test('an admin can cancel any booking, freeing the slot', () async {
      final slot = slotOn(now.day, 14);
      final repo = FakeBookingRepository();
      final other = repo.bookAsSomeoneElse(slot, otherUserId: 'cust-A');
      final provider = await signedInAdmin(repo);

      await provider.cancel(other.id);

      expect(provider.appointmentsOn(slot.date), isEmpty,
          reason: 'dropped from the loaded month');
      expect(repo.appointments.single.isCancelled, isTrue);
      final freed = await repo.fetchBookedSlots(slot.date, slot.date);
      expect(freed.contains(slot), isFalse);
    });

    test('sign out drops the session and the loaded schedule', () async {
      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(now.day, 14), otherUserId: 'cust-A');
      final provider = await signedInAdmin(repo);
      expect(provider.appointmentsOn(dayInThisMonth(now.day)), isNotEmpty);

      await provider.signOut();

      expect(provider.auth, AdminAuthState.signedOut);
      expect(provider.daysWithAppointments, isEmpty);
      expect(await repo.isCurrentUserAdmin(), isFalse);
    });
  });

  group('Admin calendar', () {
    test('opens on today', () async {
      final repo = FakeBookingRepository();
      final provider = await signedInAdmin(repo);

      final today = DateTime(now.year, now.month, now.day);
      expect(provider.selectedDay, today);
      expect(provider.visibleMonth, DateTime(now.year, now.month));
    });

    test('the day list is only the selected day\'s appointments', () async {
      // Two different days this month; pick a pair that both fit.
      final a = now.day <= 27 ? now.day : 1;
      final b = a == 1 ? 2 : 1;
      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(a, 10), otherUserId: 'cust-A')
        ..bookAsSomeoneElse(slotOn(b, 12), otherUserId: 'cust-B');
      final provider = await signedInAdmin(repo);

      provider.selectDay(dayInThisMonth(a));
      expect(provider.selectedDayAppointments.length, 1);
      expect(provider.selectedDayAppointments.single.userId, 'cust-A');

      provider.selectDay(dayInThisMonth(b));
      expect(provider.selectedDayAppointments.single.userId, 'cust-B');
    });

    test('days with appointments are marked, others are not', () async {
      final marked = now.day <= 27 ? now.day : 1;
      final unmarked = marked == 1 ? 2 : 1;
      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(marked, 10), otherUserId: 'cust-A');
      final provider = await signedInAdmin(repo);

      expect(provider.daysWithAppointments, contains(dayInThisMonth(marked)));
      expect(provider.daysWithAppointments,
          isNot(contains(dayInThisMonth(unmarked))));
    });

    test('a cancelled booking loses its day marker', () async {
      final slot = slotOn(now.day, 14);
      final repo = FakeBookingRepository();
      final other = repo.bookAsSomeoneElse(slot, otherUserId: 'cust-A');
      final provider = await signedInAdmin(repo);
      expect(provider.daysWithAppointments, contains(slot.date));

      await provider.cancel(other.id);

      expect(provider.daysWithAppointments, isNot(contains(slot.date)));
    });

    test('a failed month load surfaces, and retry reloads', () async {
      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(now.day, 14), otherUserId: 'cust-A');
      final provider = await signedInAdmin(repo);
      expect(provider.listState, LoadState.ready);

      repo.failOnLoad = const BookingOfflineException();
      await provider.loadMonth(provider.visibleMonth);
      expect(provider.listState, LoadState.failed);
      expect(provider.listError, isA<BookingOfflineException>());

      repo.failOnLoad = null;
      await provider.loadMonth(provider.visibleMonth);
      expect(provider.listState, LoadState.ready);
    });
  });

  group('Admin UI', () {
    Widget wrap(FakeBookingRepository repo, {Locale locale = const Locale('en')}) {
      return MultiProvider(
        providers: [Provider<BookingRepository>.value(value: repo)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminApp(),
        ),
      );
    }

    testWidgets('login, then the schedule shows today\'s appointment',
        (tester) async {
      // Phone-sized surface: the calendar + day list need more height than the
      // default 800x600 test viewport.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = FakeBookingRepository()
        ..bookAsSomeoneElse(slotOn(now.day, 10), otherUserId: 'cust-A');

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('Schedule'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        password,
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // The calendar schedule, defaulting to today, shows the customer booked
      // for today.
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Other Customer'), findsOneWidget);
    });

    testWidgets('a wrong password keeps the user on the login screen',
        (tester) async {
      final repo = FakeBookingRepository();

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'nope',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.text('Schedule'), findsNothing);
    });
  });
}
