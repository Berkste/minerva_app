import 'package:intl/intl.dart';

import '../models/appointment.dart';

/// Date and time formatting used across the booking flow.
///
/// Centralised so every screen shows the exact same shapes: "Friday, 14 August
/// 2026" for dates and 24-hour "16:00" for times.
class Fmt {
  const Fmt._();

  static final DateFormat _fullDate = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  /// "Friday, 14 August 2026"
  static String fullDate(DateTime date) => _fullDate.format(date);

  /// "14 Aug 2026"
  static String shortDate(DateTime date) => _shortDate.format(date);

  /// "August 2026"
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// "16:00" — 24-hour, zero padded.
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// "16:00" from a bare hour.
  static String hour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  /// "16:00 – 18:00"
  static String timeRange(DateTime start) =>
      '${time(start)} – ${time(start.add(kAppointmentDuration))}';

  /// "2 hours"
  static String durationLabel() => '${kAppointmentDuration.inHours} hours';
}

/// True when the two dates fall on the same calendar day.
bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
