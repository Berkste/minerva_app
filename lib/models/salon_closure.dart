import 'package:flutter/foundation.dart';

import 'slot.dart';

/// A stretch of days the salon has declared shut — a holiday, a closure, a
/// single day off.
///
/// Sundays are not in here. They are a standing rule rather than a decision
/// somebody made, so the database enforces them directly and the calendar
/// treats them the same way it treats these.
@immutable
class SalonClosure {
  const SalonClosure({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  final String id;

  /// Inclusive. A single day off has [startDate] equal to [endDate].
  final DateTime startDate;
  final DateTime endDate;

  final String? reason;

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  bool get isSingleDay => startDate == endDate;

  factory SalonClosure.fromRow(Map<String, dynamic> row) => SalonClosure(
        id: row['id'] as String,
        startDate: Slot.parseDate(row['start_date'] as String),
        endDate: Slot.parseDate(row['end_date'] as String),
        reason: row['reason'] as String?,
      );

  Map<String, dynamic> toInsert() => {
        'start_date': Slot(startDate, 0).dateKey,
        'end_date': Slot(endDate, 0).dateKey,
        'reason': reason,
      };

  @override
  bool operator ==(Object other) => other is SalonClosure && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
