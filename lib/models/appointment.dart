import 'package:flutter/foundation.dart';

import 'slot.dart';

/// How long every appointment lasts. The salon books a single fixed slot
/// length, which is why the time grid steps in two-hour increments.
const Duration kAppointmentDuration = Duration(hours: 2);

/// Whether a booking still stands.
enum AppointmentStatus {
  confirmed,
  cancelled;

  static AppointmentStatus fromName(String? value) =>
      value == 'cancelled' ? cancelled : confirmed;
}

/// A booking, as stored in Supabase.
///
/// The contact fields are a snapshot taken when the booking was made — the
/// customer's current details live on their profile. Keeping both means
/// editing a profile never rewrites the history of past visits.
@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.userId,
    required this.slot,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.serviceId,
    this.status = AppointmentStatus.confirmed,
    this.createdAt,
  });

  /// Server-generated uuid.
  final String id;

  /// The `auth.uid()` that booked it.
  final String userId;

  final Slot slot;

  final String firstName;
  final String lastName;

  /// Ten significant digits, no separators — the shape the database accepts.
  final String phone;

  /// Null when the customer skipped the (optional) service step.
  final String? serviceId;

  final AppointmentStatus status;
  final DateTime? createdAt;

  /// Start of the slot, as salon-local wall clock.
  DateTime get start => slot.start;

  DateTime get end => start.add(kAppointmentDuration);

  String get fullName => '$firstName $lastName';

  bool get isCancelled => status == AppointmentStatus.cancelled;

  /// True while the appointment still stands and has not yet finished.
  bool isUpcoming({DateTime? now}) =>
      !isCancelled && end.isAfter(now ?? DateTime.now());

  Appointment copyWith({
    String? id,
    String? userId,
    Slot? slot,
    String? firstName,
    String? lastName,
    String? phone,
    String? serviceId,
    AppointmentStatus? status,
    DateTime? createdAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      slot: slot ?? this.slot,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      serviceId: serviceId ?? this.serviceId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// The columns the client is allowed to write. `id`, `status` and timestamps
  /// are left to the database.
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'slot_date': slot.dateKey,
        'slot_hour': slot.hour,
        'service_id': serviceId,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      };

  factory Appointment.fromRow(Map<String, dynamic> row) {
    return Appointment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      slot: Slot(
        Slot.parseDate(row['slot_date'] as String),
        (row['slot_hour'] as num).toInt(),
      ),
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      serviceId: row['service_id'] as String?,
      status: AppointmentStatus.fromName(row['status'] as String?),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'] as String),
    );
  }

  /// Local cache representation. Same shape as a database row, so one parser
  /// serves both.
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'slot_date': slot.dateKey,
        'slot_hour': slot.hour,
        'service_id': serviceId,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'status': status.name,
        'created_at': createdAt?.toIso8601String(),
      };

  factory Appointment.fromJson(Map<String, dynamic> json) =>
      Appointment.fromRow(json);

  @override
  bool operator ==(Object other) => other is Appointment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
