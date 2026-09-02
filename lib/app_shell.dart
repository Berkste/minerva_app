import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'theme/app_theme.dart';

/// The [MaterialApp] both entry points run on — the customer app
/// (`lib/main.dart`) and the internal admin app (`lib/main_admin.dart`).
///
/// It carries only the cross-cutting shell: theme, localization, locale
/// resolution, and the text-scale clamp. It deliberately references nothing
/// under `lib/admin/`, so pulling it into the customer entry never drags admin
/// code into the store build — the two builds differ only in their [home].
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.localeProvider,
    required this.home,
  });

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
