import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';
import '../models/profile.dart';

/// Last-known appointments and profile, kept on the device.
///
/// Supabase is the source of truth; this exists so the app still shows the
/// customer their next appointment when the network is down. It is only ever
/// read as a fallback, and never used to decide whether a slot is free —
/// availability is always a live question.
class LocalCache {
  static const String _appointmentsKey = 'minerva.cache.appointments.v2';
  static const String _profileKey = 'minerva.cache.profile.v2';

  Future<List<Appointment>> readAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appointmentsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_tryParseAppointment)
          .whereType<Appointment>()
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> writeAppointments(List<Appointment> appointments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _appointmentsKey,
      jsonEncode(appointments.map((a) => a.toJson()).toList(growable: false)),
    );
  }

  Future<Profile?> readProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Profile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(Profile? profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile == null) {
      await prefs.remove(_profileKey);
    } else {
      await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    }
  }

  /// Clears everything. Used when the signed-in user changes.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appointmentsKey);
    await prefs.remove(_profileKey);
  }

  static Appointment? _tryParseAppointment(Map<String, dynamic> json) {
    try {
      return Appointment.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
