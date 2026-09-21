import 'package:flutter/foundation.dart';

/// A person the salon knows, identified by their phone number.
///
/// This replaces the old per-device profile. A device is not a person: someone
/// may reinstall the app, change phones, or have been entered by the salon
/// before they ever downloaded anything. The phone number is what carries an
/// identity across all of that, and `customer_devices` is what links whichever
/// device is in hand to the person using it.
///
/// There is no password and no verification code. A device proves nothing
/// beyond "somebody typed this number", which is why claiming a record also
/// requires the first name to match, and why a claimed record shows only
/// future appointments. That is friction rather than security, and it is a
/// deliberate trade-off — see FAZ2_ANALIZ.md.
@immutable
class Customer {
  const Customer({
    required this.id,
    required this.firstName,
    required this.phone,
    this.lastName,
    this.createdByAdmin = false,
    this.updatedAt,
  });

  /// Server-generated uuid. Unrelated to `auth.uid()`.
  final String id;

  final String firstName;

  /// Optional: only a first name and a phone number are needed to book.
  final String? lastName;

  /// Ten significant digits, no separators — the shape the database accepts.
  final String phone;

  /// True when the salon entered this person rather than the person
  /// themselves. Used to explain, not to restrict.
  final bool createdByAdmin;

  final DateTime? updatedAt;

  /// The name to show. Falls back to the first name alone, which is the whole
  /// point of the surname being optional.
  String get displayName {
    final surname = lastName?.trim() ?? '';
    return surname.isEmpty ? firstName : '$firstName $surname';
  }

  Customer copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    bool clearLastName = false,
  }) {
    return Customer(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: clearLastName ? null : (lastName ?? this.lastName),
      phone: phone ?? this.phone,
      createdByAdmin: createdByAdmin,
      updatedAt: updatedAt,
    );
  }

  /// The columns a customer is allowed to change about themselves.
  Map<String, dynamic> toUpdate() => {
        'first_name': firstName,
        'last_name': _nullIfBlank(lastName),
        'phone': phone,
      };

  factory Customer.fromRow(Map<String, dynamic> row) => Customer(
        id: row['id'] as String,
        firstName: row['first_name'] as String? ?? '',
        lastName: _nullIfBlank(row['last_name'] as String?),
        phone: row['phone'] as String? ?? '',
        createdByAdmin: row['created_by_admin'] as bool? ?? false,
        updatedAt: row['updated_at'] == null
            ? null
            : DateTime.tryParse(row['updated_at'] as String),
      );

  /// Local cache representation. Same shape as a database row, so one parser
  /// serves both.
  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'created_by_admin': createdByAdmin,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) =>
      Customer.fromRow(json);

  @override
  bool operator ==(Object other) => other is Customer && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
