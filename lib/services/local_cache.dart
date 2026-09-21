import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';
import '../models/customer.dart';

/// Last-known appointments and customer record, kept on the device.
///
/// Supabase is the source of truth; this exists so the app still shows the
/// customer their next appointment when the network is down. It is only ever
/// read as a fallback, and never used to decide whether a slot is free —
/// availability is always a live question.
class LocalCache {
  // v3: the cached shapes changed with the customers schema, and a v2 blob
  // would parse into nonsense rather than fail loudly. New keys let the old
  // ones simply go unread.
  static const String _appointmentsKey = 'minerva.cache.appointments.v3';
  static const String _customerKey = 'minerva.cache.customer.v3';

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

  Future<Customer?> readCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customerKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Customer.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCustomer(Customer? customer) async {
    final prefs = await SharedPreferences.getInstance();
    if (customer == null) {
      await prefs.remove(_customerKey);
    } else {
      await prefs.setString(_customerKey, jsonEncode(customer.toJson()));
    }
  }

  /// Clears everything. Used when the signed-in user changes.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appointmentsKey);
    await prefs.remove(_customerKey);
  }

  static Appointment? _tryParseAppointment(Map<String, dynamic> json) {
    try {
      return Appointment.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
