import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'l10n/app_localizations.dart';
import 'providers/appointment_provider.dart';
import 'providers/availability_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/setup_required_screen.dart';
import 'screens/splash_screen.dart';
import 'services/booking_repository.dart';
import 'services/supabase_booking_repository.dart';
import 'theme/app_theme.dart';

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
      return _MaterialShell(
        localeProvider: LocaleProvider()..load(),
        home: const SetupRequiredScreen(),
      );
    }

    return MultiProvider(
      providers: [
        Provider<BookingRepository>.value(value: repository),

        // Signs in, then loads this device's bookings and profile.
        ChangeNotifierProvider(
          create: (_) => AppointmentProvider(repository)..load(),
        ),

        // Live slot availability for the day being viewed.
        ChangeNotifierProvider(
          create: (_) => AvailabilityProvider(repository),
        ),

        // The booking currently being filled in.
        ChangeNotifierProvider(create: (_) => BookingProvider()),

        // The language choice, restored from the previous session.
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) => _MaterialShell(
          localeProvider: localeProvider,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// The MaterialApp itself, shared by the configured and unconfigured cases.
class _MaterialShell extends StatelessWidget {
  const _MaterialShell({required this.localeProvider, required this.home});

  final LocaleProvider localeProvider;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,

      // Null locale means "follow the device"; the resolution callback falls
      // back to Turkish for any language we do not ship.
      locale: localeProvider.locale,
      supportedLocales: LocaleProvider.supportedLocales,
      localeResolutionCallback: LocaleProvider.resolve,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: home,
      builder: (context, child) {
        // Clamp text scaling: past ~1.3x the fixed-height chips and cards
        // start to clip, so this keeps large-font devices readable.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
