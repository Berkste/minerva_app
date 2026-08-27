import 'package:flutter/foundation.dart';

/// How long every appointment lasts. The salon books a single fixed slot
/// length, which is why the time grid steps in two-hour increments.
const Duration kAppointmentDuration = Duration(hours: 2);

/// A confirmed booking, as persisted to local storage.
@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.start,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.serviceId,
  });

  final String id;

  /// Start of the slot, at local time. Minutes are always zero.
  final DateTime start;

  final String firstName;
  final String lastName;
  final String phone;

  /// Null when the customer skipped the (optional) service step.
  final String? serviceId;

  DateTime get end => start.add(kAppointmentDuration);

  String get fullName => '$firstName $lastName';

  /// True while the appointment has not yet finished.
  bool isUpcoming({DateTime? now}) => end.isAfter(now ?? DateTime.now());

  Appointment copyWith({
    String? id,
    DateTime? start,
    String? firstName,
    String? lastName,
    String? phone,
    String? serviceId,
  }) {
    return Appointment(
      id: id ?? this.id,
      start: start ?? this.start,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      serviceId: serviceId ?? this.serviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'serviceId': serviceId,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      start: DateTime.parse(json['start'] as String),
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      serviceId: json['serviceId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Appointment && other.id == id && other.start == start;

  @override
  int get hashCode => Object.hash(id, start);
}
