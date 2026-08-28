import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minerva_app/l10n/app_localizations.dart';
import 'package:minerva_app/models/appointment.dart';
import 'package:minerva_app/models/profile.dart';
import 'package:minerva_app/models/slot.dart';
import 'package:minerva_app/providers/availability_provider.dart';
import 'package:minerva_app/screens/setup_required_screen.dart';
import 'package:minerva_app/providers/appointment_provider.dart';
import 'package:minerva_app/providers/booking_provider.dart';
import 'package:minerva_app/providers/locale_provider.dart';
import 'package:minerva_app/screens/appointments_screen.dart';
import 'package:minerva_app/screens/booking/calendar_screen.dart';
import 'package:minerva_app/screens/booking/details_screen.dart';
import 'package:minerva_app/screens/booking/review_screen.dart';
import 'package:minerva_app/screens/booking/service_screen.dart';
import 'package:minerva_app/screens/booking/success_screen.dart';
import 'package:minerva_app/screens/booking/time_screen.dart';
import 'package:minerva_app/screens/home_screen.dart';
import 'package:minerva_app/screens/main_shell.dart';
import 'package:minerva_app/screens/profile_screen.dart';
import 'package:minerva_app/screens/splash_screen.dart';
import 'package:minerva_app/theme/app_theme.dart';

import 'fake_booking_repository.dart';

/// Renders every screen at several phone sizes and text scales.
///
/// A RenderFlex overflow or an unbounded-constraint error is reported as a
/// thrown exception in widget tests, so simply pumping each screen is a real
/// check that the responsive layout holds up.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  /// Small phone, mainstream phone, large phone.
  const sizes = <String, Size>{
    'small (360x640)': Size(360, 640),
    'medium (390x844)': Size(390, 844),
    'large (430x932)': Size(430, 932),
  };

  /// The extremes the app clamps text scaling to.
  const textScales = <double>[0.9, 1.3];

  // Turkish strings are longer than their English counterparts on several
  // screens, so both languages have to be checked for overflow.
  final locales = LocaleProvider.supportedLocales;

  final sampleSlot = Slot(DateTime.now().add(const Duration(days: 3)), 16);

  final sampleAppointment = Appointment(
    id: 'sample',
    userId: 'user-1',
    slot: sampleSlot,
    firstName: 'Elif',
    lastName: 'Yilmaz',
    phone: '5551234567',
    serviceId: 'classic_manicure',
  );

  /// A fully-populated draft, so review/success render their richest state.
  BookingProvider filledBooking() => BookingProvider()
    ..selectDate(DateTime.now().add(const Duration(days: 3)))
    ..selectHour(16)
    ..setDetails(
      firstName: 'Elif',
      lastName: 'Yilmaz',
      phone: '+90 555 123 45 67',
    )
    ..selectService('classic_manicure');

  final screens = <String, Widget Function()>{
    'Splash': () => const SplashScreen(),
    'MainShell (Home)': () => const MainShell(),
    'Home': () => const HomeScreen(),
    'Calendar': () => const CalendarScreen(),
    'Time': () => const TimeScreen(),
    'Details': () => const DetailsScreen(),
    'Service': () => const ServiceScreen(),
    'Review': () => const ReviewScreen(),
    'Success': () => SuccessScreen(appointment: sampleAppointment),
    'Appointments': () => const AppointmentsScreen(),
    'Profile': () => const ProfileScreen(),
    'SetupRequired': () => const SetupRequiredScreen(),
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

                final repo = FakeBookingRepository()
                  ..appointments.add(sampleAppointment)
                  ..profile = const Profile(
                    id: 'user-1',
                    firstName: 'Elif',
                    lastName: 'Yilmaz',
                    phone: '5551234567',
                  );

                final appointments = AppointmentProvider(repo);
                await appointments.load();

                await tester.pumpWidget(
                  MultiProvider(
                    providers: [
                      ChangeNotifierProvider.value(value: appointments),
                      ChangeNotifierProvider.value(value: filledBooking()),
                      ChangeNotifierProvider(
                        create: (_) => AvailabilityProvider(repo),
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
                          child: screenEntry.value(),
                        ),
                      ),
                    ),
                  ),
                );

                await tester.pumpAndSettle();

                // pumpAndSettle rethrows layout/paint errors, so reaching here
                // means the screen laid out and painted without complaint.
                expect(tester.takeException(), isNull);
              });
            }
          },
        );
      }
    }
  }
}
