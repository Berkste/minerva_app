import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's language choice and remembers it between launches.
///
/// A null [locale] means "follow the device", which is the default. When the
/// device language is neither Turkish nor English the app falls back to
/// Turkish (see [resolve]).
class LocaleProvider extends ChangeNotifier {
  static const String _key = 'minerva.locale.v1';

  /// Languages the app ships strings for.
  static const List<Locale> supportedLocales = [
    Locale('tr'),
    Locale('en'),
  ];

  /// Used when the device language is not one we support.
  static const Locale fallbackLocale = Locale('tr');

  Locale? _locale;

  /// The explicit choice, or null while following the device.
  Locale? get locale => _locale;

  /// Reads the stored choice. Safe to call more than once.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  /// Passing null goes back to following the device language.
  Future<void> setLocale(Locale? value) async {
    if (_locale == value) return;
    _locale = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, value.languageCode);
    }
  }

  /// Picks the locale to render in, given what the device asks for.
  ///
  /// Wired to MaterialApp.localeResolutionCallback so an unsupported device
  /// language lands on Turkish rather than on the first supported entry.
  static Locale resolve(Locale? deviceLocale, Iterable<Locale> supported) {
    if (deviceLocale != null) {
      for (final candidate in supported) {
        if (candidate.languageCode == deviceLocale.languageCode) {
          return candidate;
        }
      }
    }
    return fallbackLocale;
  }
}
