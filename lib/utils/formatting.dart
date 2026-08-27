import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import 'phone_formatter.dart';

/// Date, time and phone formatting used across the booking flow.
///
/// Centralised so every screen shows the exact same shapes. Date patterns come
/// from the ARB files, because the two languages order their parts
/// differently: "Friday, 14 August 2026" vs "14 Ağustos 2026 Cuma".
class Fmt {
  const Fmt._(this._l10n, this._localeName);

  /// Reads the active locale and strings from the widget tree.
  factory Fmt.of(BuildContext context) => Fmt._(
        AppLocalizations.of(context),
        Localizations.localeOf(context).languageCode,
      );

  final AppLocalizations _l10n;
  final String _localeName;

  /// "14 Ağustos 2026 Cuma" / "Friday, 14 August 2026"
  String fullDate(DateTime date) =>
      DateFormat(_l10n.dateFullPattern, _localeName).format(date);

  /// "14 Ağu 2026" / "14 Aug 2026"
  String shortDate(DateTime date) =>
      DateFormat(_l10n.dateShortPattern, _localeName).format(date);

  /// "Ağustos 2026" / "August 2026"
  String monthYear(DateTime date) =>
      DateFormat(_l10n.monthYearPattern, _localeName).format(date);

  /// Short weekday captions for the calendar header, Monday first.
  ///
  /// Taken from intl rather than hard-coded, so Turkish gets Pzt/Sal/Çar/…
  List<String> weekdayLabels() {
    final format = DateFormat.E(_localeName);
    // 2024-01-01 was a Monday; seven days from there covers the whole week.
    final monday = DateTime(2024, 1, 1);
    return List.generate(
      7,
      (i) => format.format(monday.add(Duration(days: i))),
    );
  }

  /// "2 saat" / "2 hours"
  String durationLabel() => _l10n.durationHours(kAppointmentDuration.inHours);

  // --- Locale-independent ---------------------------------------------------
  // Times are always 24-hour and zero padded in both languages.

  /// "16:00"
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// "16:00" from a bare hour.
  static String hour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  /// "16:00 – 18:00"
  static String timeRange(DateTime start) =>
      '${time(start)} – ${time(start.add(kAppointmentDuration))}';

  /// Renders a stored number as "(555) 555 55 55".
  ///
  /// Numbers saved before this format existed are re-masked on display, and
  /// anything that cannot be parsed is shown unchanged rather than mangled.
  static String phone(String raw) {
    final digits = TurkishPhoneInputFormatter.extractDigits(raw);
    if (digits.length != kPhoneDigitCount) return raw;
    return TurkishPhoneInputFormatter.format(digits);
  }
}

/// True when the two dates fall on the same calendar day.
bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
