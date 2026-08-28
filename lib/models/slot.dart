import 'package:flutter/foundation.dart';

/// A bookable slot, expressed the way the salon thinks about it: a calendar
/// day plus an hour on the clock on the wall.
///
/// Slots are deliberately *not* instants. Two phones in different time zones
/// would turn "14:00" into two different instants, and the database's
/// uniqueness rule would then let both of them book what the salon considers
/// the same slot. Keeping the wall-clock pair as the identity makes the slot
/// mean the same thing everywhere.
@immutable
class Slot {
  Slot(DateTime date, this.hour)
      : date = DateTime(date.year, date.month, date.day);

  /// Midnight on the day of the slot. Never carries a time component.
  final DateTime date;

  /// Hour the slot starts, on a 24-hour clock.
  final int hour;

  /// Start of the slot as a local [DateTime], for formatting and comparison
  /// against the device clock.
  DateTime get start => DateTime(date.year, date.month, date.day, hour);

  /// "2026-09-04", the shape Postgres expects for a `date` column.
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime parseDate(String value) {
    final parts = value.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Slot && other.date == date && other.hour == hour;

  @override
  int get hashCode => Object.hash(date, hour);

  @override
  String toString() => '$dateKey@$hour';
}
