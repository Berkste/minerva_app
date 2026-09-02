import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_app.dart';
import 'app_shell.dart';
import 'config/supabase_config.dart';
import 'providers/locale_provider.dart';
import 'screens/setup_required_screen.dart';
import 'services/booking_repository.dart';
import 'services/supabase_booking_repository.dart';

/// Admin / employee entry point — a SEPARATE build for salon staff, never
/// shipped to the app stores. Build it with:
///
///   flutter build appbundle --release -t lib/main_admin.dart \
///     --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
///
/// It shares the theme, localization and Supabase setup with the customer app
/// but launches straight into the staff login instead of the customer flow. It
/// deliberately does NOT anonymously sign in (staff authenticate with email +
/// password), and it wires none of the customer booking providers.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting();

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

  if (!SupabaseConfig.isConfigured) {
    runApp(const MinervaAdminApp.unconfigured());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(
    MinervaAdminApp(
      repository: SupabaseBookingRepository(Supabase.instance.client),
    ),
  );
}

class MinervaAdminApp extends StatelessWidget {
  const MinervaAdminApp({super.key, required BookingRepository this.repository});

  /// Builds the app in its "no credentials" state.
  const MinervaAdminApp.unconfigured({super.key}) : repository = null;

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
        // The admin screens reach the backend through the same repository; its
        // admin methods are gated by the database's is_admin() RLS policies, so
        // no privileged client is needed. AdminProvider is created inside
        // AdminApp itself.
        Provider<BookingRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) => AppShell(
          localeProvider: localeProvider,
          home: const AdminApp(),
        ),
      ),
    );
  }
}
