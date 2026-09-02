import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/admin_provider.dart';
import '../services/booking_repository.dart';
import 'admin_appointments_screen.dart';
import 'admin_login_screen.dart';

/// Entry point for the admin/employee flow.
///
/// This is the `home` of the separate admin build (`lib/main_admin.dart`); the
/// customer app does not reference it at all. It owns a single [AdminProvider]
/// for the whole flow and shows login or the schedule depending on auth state —
/// so signing out returns to the login screen reactively, with nothing to pop.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

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
