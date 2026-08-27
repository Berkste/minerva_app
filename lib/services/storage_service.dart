import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';

/// Thin wrapper over [SharedPreferences] that reads and writes the appointment
/// list as a single JSON array.
///
/// The data set is tiny (a handful of bookings per device), so a document-style
/// store beats a database here — no schema, no migrations, no codegen.
class StorageService {
  static const String _appointmentsKey = 'minerva.appointments.v1';

  /// Returns every stored appointment. Malformed entries are dropped rather
  /// than crashing the app, so a bad write can never brick the list.
  Future<List<Appointment>> loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appointmentsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_tryParse)
          .whereType<Appointment>()
          .toList();
    } on FormatException {
      return [];
    }
  }

  /// Overwrites the stored list with [appointments].
  Future<void> saveAppointments(List<Appointment> appointments) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(appointments.map((a) => a.toJson()).toList(growable: false));
    await prefs.setString(_appointmentsKey, encoded);
  }

  static Appointment? _tryParse(Map<String, dynamic> json) {
    try {
      return Appointment.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
