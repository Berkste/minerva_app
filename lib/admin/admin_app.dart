import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../services/booking_repository.dart';
import 'admin_appointments_screen.dart';
import 'admin_login_screen.dart';

/// Entry point for the admin/employee flow.
///
/// Pushed as its own route from a discreet control on the Profile screen, so it
/// stays out of the customer's normal path. It owns a single [AdminProvider]
/// for the whole flow and shows login or the schedule depending on auth state.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AdminApp());

  @override
  Widget build(BuildContext context) {
    // Reuse the app's existing repository — the admin methods on it are gated
    // by the database's is_admin() policies, so no privileged client is needed.
    final repository = context.read<BookingRepository>();

    return ChangeNotifierProvider(
      create: (_) => AdminProvider(repository),
      child: const _AdminGate(),
    );
  }
}

/// Shows the login screen until a staff member is authenticated, then the
/// salon-wide appointment list.
class _AdminGate extends StatelessWidget {
  const _AdminGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.select<AdminProvider, AdminAuthState>((p) => p.auth);

    return switch (auth) {
      AdminAuthState.authenticated => const AdminAppointmentsScreen(),
      _ => const AdminLoginScreen(),
    };
  }
}
