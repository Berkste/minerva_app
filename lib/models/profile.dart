import 'package:flutter/foundation.dart';

/// The customer's saved contact details, keyed by their Supabase user id.
///
/// A device starts as a guest with no profile row. The first completed booking
/// writes one, and later bookings keep it up to date — which is what turns a
/// guest into a returning customer without ever asking anyone to register.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.updatedAt,
  });

  /// Matches `auth.uid()`.
  final String id;

  final String firstName;
  final String lastName;

  /// Ten significant digits, no separators.
  final String phone;

  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toUpsert() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      };

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        firstName: row['first_name'] as String? ?? '',
        lastName: row['last_name'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        updatedAt: row['updated_at'] == null
            ? null
            : DateTime.tryParse(row['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        ...toUpsert(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile.fromRow(json);
}
