import 'package:flutter/foundation.dart';

import 'salon_service.dart';
import 'slot.dart';

/// How long every appointment lasts. The salon books a single fixed slot
/// length, which is why the time grid steps in two-hour increments.
const Duration kAppointmentDuration = Duration(hours: 2);

/// How long after the slot starts a booking counts as having happened.
///
/// Nothing writes this status on a schedule: an appointment an hour past its
/// start, still confirmed, simply *is* a completed one. Keeping it derived
/// means no background job to install, watch, or discover has quietly stopped.
const Duration kCompletedAfter = Duration(hours: 1);

/// Whether a booking still stands, and how it ended if it did not.
enum AppointmentStatus {
  /// The slot is held.
  confirmed,

  /// Called off. Frees the slot.
  cancelled,

  /// It happened. Staff can set this explicitly; otherwise it is derived.
  completed,

  /// The customer did not come. Frees the slot, and — because they received
  /// no service — releases them from the 21-day booking window too. Marking
  /// somebody a no-show is what lets them book again.
  noShow;

  static AppointmentStatus fromName(String? value) => switch (value) {
        'cancelled' => cancelled,
        'completed' => completed,
        'no_show' => noShow,
        _ => confirmed,
      };

  String get wireName => this == noShow ? 'no_show' : name;
}

/// Who ended an appointment.
enum CancelledBy {
  customer,
  admin;

  static CancelledBy? fromName(String? value) => switch (value) {
        'customer' => customer,
        'admin' => admin,
        _ => null,
      };
}

/// A booking, as stored in Supabase.
///
/// The contact fields are a snapshot taken when the booking was made — the
/// person's current details live on their customer record. Keeping both means
/// editing a phone number never rewrites the history of past visits.
@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.customerId,
    required this.slot,
    required this.firstName,
    required this.phone,
    this.lastName,
    this.services = const [],
    this.status = AppointmentStatus.confirmed,
    this.createdByAdmin = false,
    this.cancelledBy,
    this.createdAt,
  });

  /// Server-generated uuid.
  final String id;

  /// The person this belongs to — not a device, and not `auth.uid()`.
  final String customerId;

  final Slot slot;

  final String firstName;

  /// Optional, like the customer's own surname.
  final String? lastName;

  /// Ten significant digits, no separators.
  final String phone;

  /// What was done, and for how much. A treatment plus any add-ons the salon
  /// recorded. Empty when the customer skipped the optional service step and
  /// nothing has been added since.
  final List<AppointmentService> services;

  final AppointmentStatus status;

  /// True when the salon entered this booking on somebody's behalf. Such a
  /// booking is not the device's to change — whoever typed the phone number
  /// into the app did not necessarily make it.
  final bool createdByAdmin;

  final CancelledBy? cancelledBy;
  final DateTime? createdAt;

  /// Start of the slot, as salon-local wall clock.
  DateTime get start => slot.start;

  DateTime get end => start.add(kAppointmentDuration);

  String get fullName {
    final surname = lastName?.trim() ?? '';
    return surname.isEmpty ? firstName : '$firstName $surname';
  }

  /// The treatment the customer chose, if any.
  AppointmentService? get mainService {
    for (final line in services) {
      if (line.kind == ServiceKind.main) return line;
    }
    return null;
  }

  List<AppointmentService> get extras =>
      services.where((s) => s.kind == ServiceKind.extra).toList();

  /// What this visit is worth. The sum of its lines and nothing else — the
  /// catalogue cannot answer this, because two add-ons are priced as a range.
  num get total => services.fold<num>(0, (sum, line) => sum + line.amount);

  bool get isCancelled => status == AppointmentStatus.cancelled;
  bool get isNoShow => status == AppointmentStatus.noShow;

  /// Whether the visit counts as having happened — either marked so, or simply
  /// an hour past a slot nobody called off.
  bool didHappen({DateTime? now}) {
    if (status == AppointmentStatus.completed) return true;
    if (status != AppointmentStatus.confirmed) return false;
    return start.add(kCompletedAfter).isBefore(now ?? DateTime.now());
  }

  /// True while the appointment still stands and has not yet finished.
  bool isUpcoming({DateTime? now}) =>
      status == AppointmentStatus.confirmed &&
      end.isAfter(now ?? DateTime.now());

  /// Whether the customer may still call this off themselves.
  ///
  /// Mirrors the `MN004` rule in the database, so the app can hide the button
  /// rather than offer it and then explain the refusal. The database is still
  /// the authority; this only saves a wasted round trip.
  bool canBeCancelledByCustomer({DateTime? now}) {
    if (status != AppointmentStatus.confirmed) return false;
    if (createdByAdmin) return false;
    return start
        .subtract(const Duration(hours: 1))
        .isAfter(now ?? DateTime.now());
  }

  /// Whether the customer may still move it. Same limits as cancelling.
  bool canBeChangedByCustomer({DateTime? now}) =>
      canBeCancelledByCustomer(now: now);

  Appointment copyWith({
    Slot? slot,
    String? firstName,
    String? lastName,
    String? phone,
    List<AppointmentService>? services,
    AppointmentStatus? status,
    CancelledBy? cancelledBy,
  }) {
    return Appointment(
      id: id,
      customerId: customerId,
      slot: slot ?? this.slot,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      services: services ?? this.services,
      status: status ?? this.status,
      createdByAdmin: createdByAdmin,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      createdAt: createdAt,
    );
  }

  factory Appointment.fromRow(Map<String, dynamic> row) {
    final lines = row['appointment_services'];
    return Appointment(
      id: row['id'] as String,
      customerId: row['customer_id'] as String? ?? '',
      slot: Slot(
        Slot.parseDate(row['slot_date'] as String),
        (row['slot_hour'] as num).toInt(),
      ),
      firstName: row['first_name'] as String? ?? '',
      lastName: (row['last_name'] as String?)?.trim().isEmpty ?? true
          ? null
          : (row['last_name'] as String).trim(),
      phone: row['phone'] as String? ?? '',
      services: lines is List
          ? lines
              .cast<Map<String, dynamic>>()
              .map(AppointmentService.fromRow)
              .toList(growable: false)
          : const [],
      status: AppointmentStatus.fromName(row['status'] as String?),
      createdByAdmin: row['created_by_admin'] as bool? ?? false,
      cancelledBy: CancelledBy.fromName(row['cancelled_by'] as String?),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'] as String),
    );
  }

  /// Local cache representation. Same shape as a database row, so one parser
  /// serves both.
  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'slot_date': slot.dateKey,
        'slot_hour': slot.hour,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'appointment_services': services.map((s) => s.toJson()).toList(),
        'status': status.wireName,
        'created_by_admin': createdByAdmin,
        'cancelled_by': cancelledBy?.name,
        'created_at': createdAt?.toIso8601String(),
      };

  factory Appointment.fromJson(Map<String, dynamic> json) =>
      Appointment.fromRow(json);

  @override
  bool operator ==(Object other) => other is Appointment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
