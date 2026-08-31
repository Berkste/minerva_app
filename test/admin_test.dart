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
///
/// The real boundary is the `is_admin()` RLS policy in the admin migration;
/// these tests pin the app's half — that it never treats a login as permission
/// and never reads the salon-wide list without the database allowing it.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  final soon = Slot(DateTime.now().add(const Duration(days: 2)), 14);
  final soon2 = Slot(DateTime.now().add(const Duration(days: 3)), 16);

  /// Seeds two customers' bookings straight into the store.
  void seedTwoBookings(FakeBookingRepository repo) {
    repo
      ..bookAsSomeoneElse(soon, otherUserId: 'cust-A')
      ..bookAsSomeoneElse(soon2, otherUserId: 'cust-B');
  }

  group('Admin authorization', () {
    test('wrong password is rejected', () async {
      final repo = FakeBookingRepository();
      final provider = AdminProvider(repo);

      final ok = await provider.signIn(
        email: 'admin@minerva.test',
        password: 'WRONG',
      );

      expect(ok, isFalse);
      expect(provider.auth, AdminAuthState.signedOut);
      expect(provider.authError, isA<InvalidAdminCredentialsException>());
    });

    test('valid credentials that are not staff are refused and signed out',
        () async {
      final repo = FakeBookingRepository()..credentialsAreAdmin = false;
      final provider = AdminProvider(repo);

      final ok = await provider.signIn(
        email: 'admin@minerva.test',
        password: 'correct-horse',
      );

      expect(ok, isFalse);
      expect(provider.auth, AdminAuthState.signedOut);
      expect(provider.authError, isA<NotAnAdminException>());
      // Logging in but not being staff must leave no session behind.
      expect(await repo.isCurrentUserAdmin(), isFalse);
    });

    test('a real staff login is authenticated and loads the schedule',
        () async {
      final repo = FakeBookingRepository();
      seedTwoBookings(repo);
      final provider = AdminProvider(repo);

      final ok = await provider.signIn(
        email: 'admin@minerva.test',
        password: 'correct-horse',
      );

      expect(ok, isTrue);
      expect(provider.auth, AdminAuthState.authenticated);
      expect(provider.listState, LoadState.ready);
      expect(provider.appointments.length, 2);
    });
  });

  group('Admin data access', () {
    test('a non-admin caller reads none of the salon-wide list', () async {
      final repo = FakeBookingRepository();
      seedTwoBookings(repo);

      // No admin sign-in — mirrors RLS returning zero rows to a customer.
      expect(await repo.fetchAllUpcomingAppointments(), isEmpty);
    });

    test('an admin sees every customer\'s upcoming appointment', () async {
      final repo = FakeBookingRepository();
      seedTwoBookings(repo);
      final provider = AdminProvider(repo);
      await provider.signIn(email: 'admin@minerva.test', password: 'correct-horse');

      final owners = provider.appointments.map((a) => a.userId).toSet();
      expect(owners, containsAll(<String>{'cust-A', 'cust-B'}));
    });

    test('a non-admin cannot cancel a booking they do not own', () async {
      final repo = FakeBookingRepository();
      final other = repo.bookAsSomeoneElse(soon, otherUserId: 'cust-A');

      // No admin session.
      await repo.adminCancel(other.id);

      expect(
        repo.appointments.single.status,
        AppointmentStatus.confirmed,
        reason: 'RLS would refuse; the fake refuses too',
      );
    });

    test('an admin can cancel any booking, freeing the slot', () async {
      final repo = FakeBookingRepository();
      final other = repo.bookAsSomeoneElse(soon, otherUserId: 'cust-A');
      final provider = AdminProvider(repo);
      await provider.signIn(email: 'admin@minerva.test', password: 'correct-horse');

      await provider.cancel(other.id);

      expect(provider.appointments, isEmpty, reason: 'dropped from the list');
      expect(repo.appointments.single.isCancelled, isTrue);
      // The slot is free again, so a new booking can take it.
      final freed = await repo.fetchBookedSlots(soon.date, soon.date);
      expect(freed.contains(soon), isFalse);
    });

    test('sign out drops the session and the loaded schedule', () async {
      final repo = FakeBookingRepository();
      seedTwoBookings(repo);
      final provider = AdminProvider(repo);
      await provider.signIn(email: 'admin@minerva.test', password: 'correct-horse');
      expect(provider.appointments, isNotEmpty);

      await provider.signOut();

      expect(provider.auth, AdminAuthState.signedOut);
      expect(provider.appointments, isEmpty);
      expect(await repo.isCurrentUserAdmin(), isFalse);
    });
  });

  group('Admin UI', () {
    Widget wrap(FakeBookingRepository repo, {Locale locale = const Locale('en')}) {
      return MultiProvider(
        providers: [
          Provider<BookingRepository>.value(value: repo),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminApp(),
        ),
      );
    }

    testWidgets('shows the login form first, then the schedule after sign-in',
        (tester) async {
      final repo = FakeBookingRepository();
      repo.bookAsSomeoneElse(soon, otherUserId: 'cust-A');

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      // Login screen up first.
      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('All Appointments'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'admin@minerva.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'correct-horse',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Now the salon-wide schedule, showing the customer's contact details.
      expect(find.text('All Appointments'), findsOneWidget);
      expect(find.text('Other Customer'), findsOneWidget);
    });

    testWidgets('a wrong password keeps the user on the login screen',
        (tester) async {
      final repo = FakeBookingRepository();

      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'admin@minerva.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'nope',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.text('All Appointments'), findsNothing);
    });
  });
}
