import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'config/supabase_config.dart';
import 'providers/appointment_provider.dart';
import 'providers/availability_provider.dart';
import 'providers/catalogue_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/setup_required_screen.dart';
import 'screens/splash_screen.dart';
import 'services/booking_repository.dart';
import 'services/supabase_booking_repository.dart';

/// Customer entry point — the build that ships to the App Store and Google
/// Play. It has no reference to anything under `lib/admin/`, so the store
/// binary contains no admin panel. Staff use the separate `lib/main_admin.dart`
/// entry (`flutter build … -t lib/main_admin.dart`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads month and weekday names for every locale, so DateFormat can render
  // Turkish dates regardless of the device language.
  await initializeDateFormatting();

  // Portrait only: every screen is a single-column layout.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Without credentials the app cannot do anything useful, so it says so
  // plainly instead of failing at the first query.
  if (!SupabaseConfig.isConfigured) {
    runApp(const MinervaApp.unconfigured());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(
    MinervaApp(
      repository: SupabaseBookingRepository(Supabase.instance.client),
    ),
  );
}

class MinervaApp extends StatelessWidget {
  const MinervaApp({super.key, required BookingRepository this.repository});

  /// Builds the app in its "no credentials" state.
  const MinervaApp.unconfigured({super.key}) : repository = null;

  /// Null only in the unconfigured case.
  final BookingRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repository = this.repository;

    if (repository == null) {
      return AppShell(
        localeProvider: LocaleProvider()..load(),
        home: const SetupRequiredScreen(),
      );
    }

    return MultiProvider(
      providers: [
        Provider<BookingRepository>.value(value: repository),

        // Loads this device's bookings and profile, if it has any. Does not
        // sign in: an identity is created on the first real booking.
        ChangeNotifierProvider(
          create: (_) => AppointmentProvider(repository)..load(),
        ),

        // Live slot availability for the day being viewed.
        ChangeNotifierProvider(
          create: (_) => AvailabilityProvider(repository),
        ),

        // The salon's treatments. Loaded once: every screen that shows a
        // treatment name resolves it from here, and it is a handful of rows
        // that change when the salon says so, not per booking.
        ChangeNotifierProvider(
          create: (_) => CatalogueProvider(repository)..load(),
        ),

        // The booking currently being filled in.
        ChangeNotifierProvider(create: (_) => BookingProvider()),

        // The language choice, restored from the previous session.
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) => AppShell(
          localeProvider: localeProvider,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
