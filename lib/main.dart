import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/appointment_provider.dart';
import 'providers/booking_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const MinervaApp());
}

class MinervaApp extends StatelessWidget {
  const MinervaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Saved bookings; starts reading from local storage immediately so the
        // home screen has data by the time the user leaves the splash.
        ChangeNotifierProvider(
          create: (_) => AppointmentProvider()..load(),
        ),
        // The booking currently being filled in.
        ChangeNotifierProvider(create: (_) => BookingProvider()),
      ],
      child: MaterialApp(
        title: 'Minerva Nail Art',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
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
      ),
    );
  }
}
