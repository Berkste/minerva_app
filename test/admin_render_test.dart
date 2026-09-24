import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minerva_app/admin/admin_appointments_screen.dart';
import 'package:minerva_app/admin/admin_book_screen.dart';
import 'package:minerva_app/admin/admin_closures_screen.dart';
import 'package:minerva_app/admin/admin_customers_screen.dart';
import 'package:minerva_app/admin/admin_login_screen.dart';
import 'package:minerva_app/admin/admin_manage_appointment_sheet.dart';
import 'package:minerva_app/admin/admin_services_screen.dart';
import 'package:minerva_app/admin/admin_stats_screen.dart';
import 'package:minerva_app/l10n/app_localizations.dart';
import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/salon_service.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/providers/admin_provider.dart';
import 'package:minerva_app/providers/catalogue_provider.dart';
import 'package:minerva_app/providers/locale_provider.dart';
import 'package:minerva_app/services/booking_repository.dart';
import 'package:minerva_app/theme/app_theme.dart';

import 'fake_booking_repository.dart';

/// Renders every staff screen at several phone sizes and text scales.
///
/// Same reasoning as the customer suite: a RenderFlex overflow is a thrown
/// exception in a widget test, so pumping each screen is a real check that
/// the layout holds. It matters more here than it looks — the admin screens
/// are dense with Turkish labels, and Turkish runs longer than English on
/// almost every one of them.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  const sizes = <String, Size>{
    'small (360x640)': Size(360, 640),
    'large (430x932)': Size(430, 932),
  };

  const textScales = <double>[0.9, 1.3];

  final locales = LocaleProvider.supportedLocales;

  /// A day the salon is open, so nothing under test lands on a Sunday.
  DateTime openDay(int daysFromNow) {
    var day = DateTime.now().add(Duration(days: daysFromNow));
    day = DateTime(day.year, day.month, day.day);
    return day.weekday == DateTime.sunday
        ? day.add(const Duration(days: 1))
        : day;
  }

  /// A booking with money on it, so the cards and sheets render their fullest
  /// state rather than their emptiest.
  Appointment sampleAppointment(String customerId) => Appointment(
        id: 'appt-sample',
        customerId: customerId,
        slot: Slot(openDay(1), 14),
        firstName: 'Zeynep',
        lastName: 'Yilmaz',
        phone: '5551234567',
        createdByAdmin: true,
        services: const [
          AppointmentService(
            id: 'line-1',
            serviceId: 'medikal_manikur',
            kind: ServiceKind.main,
            amount: 450,
          ),
        ],
      );

  /// A repository with a signed-in salon, one customer, one booking and one
  /// declared closure — enough for every screen to have something to draw.
  Future<FakeBookingRepository> populatedRepo() async {
    final repo = FakeBookingRepository();
    await repo.adminSignIn(
      email: repo.validAdminEmail,
      password: repo.validAdminPassword,
    );

    final customer = await repo.claimCustomer(
      firstName: 'Zeynep',
      lastName: 'Yilmaz',
      phone: '5551234567',
    );
    repo.appointments.add(sampleAppointment(customer.id));
    await repo.addClosure(
      from: openDay(10),
      to: openDay(12),
      reason: 'Tatil',
    );

    return repo;
  }

  final screens = <String, Widget Function(FakeBookingRepository)>{
    'AdminLogin': (_) => const AdminLoginScreen(),
    'AdminSchedule': (_) => const AdminAppointmentsScreen(),
    'AdminCustomers': (_) => const AdminCustomersScreen(),
    'AdminServices': (_) => const AdminServicesScreen(),
    'AdminClosures': (_) => const AdminClosuresScreen(),
    'AdminStats': (_) => const AdminStatsScreen(),
    'AdminNewBooking': (_) => const AdminBookScreen(),
    'ManageAppointment': (repo) => ManageAppointmentSheet(
          appointment: repo.appointments.first,
        ),
  };

  for (final locale in locales) {
    for (final sizeEntry in sizes.entries) {
      for (final textScale in textScales) {
        group(
          '[${locale.languageCode}] ${sizeEntry.key} @ ${textScale}x text',
          () {
            for (final screenEntry in screens.entries) {
              testWidgets('${screenEntry.key} renders cleanly', (tester) async {
                SharedPreferences.setMockInitialValues({});

                tester.view.physicalSize = sizeEntry.value * 3;
                tester.view.devicePixelRatio = 3;
                addTearDown(tester.view.reset);

                final repo = await populatedRepo();

                final admin = AdminProvider(repo);
                await admin.signIn(
                  email: repo.validAdminEmail,
                  password: repo.validAdminPassword,
                );

                await tester.pumpWidget(
                  MultiProvider(
                    providers: [
                      Provider<BookingRepository>.value(value: repo),
                      ChangeNotifierProvider.value(value: admin),
                      ChangeNotifierProvider(
                        create: (_) => CatalogueProvider(repo)..load(),
                      ),
                      ChangeNotifierProvider(create: (_) => LocaleProvider()),
                    ],
                    child: MaterialApp(
                      theme: AppTheme.light,
                      locale: locale,
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: Builder(
                        builder: (context) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(textScale),
                          ),
                          // The sheets are normally shown modally; rendering
                          // them as a page is enough to catch a layout that
                          // does not fit, which is what this suite is for.
                          child: Material(
                            child: screenEntry.value(repo),
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                await tester.pumpAndSettle();

                // pumpAndSettle rethrows layout and paint errors, so reaching
                // here means the screen laid out without complaint.
                expect(tester.takeException(), isNull);
              });
            }
          },
        );
      }
    }
  }
}
