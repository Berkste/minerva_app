import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../models/salon_service.dart';
import '../providers/admin_provider.dart';
import '../providers/appointment_provider.dart' show LoadState;
import '../services/booking_exception.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';

/// The salon-wide schedule: every customer's upcoming appointment, with the
/// contact details staff need and the ability to cancel any of them.
class AdminAppointmentsScreen extends StatelessWidget {
  const AdminAppointmentsScreen({super.key});

  Future<void> _confirmCancel(
    BuildContext context,
    Appointment appointment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(l10n.cancelAppointmentTitle, style: const TextStyle(fontSize: 17)),
        content: Text(
          l10n.adminCancelConfirmBody(
            appointment.fullName,
            fmt.shortDate(appointment.start),
            Fmt.time(appointment.start),
          ),
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.keepIt),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05C87)),
            child: Text(l10n.cancelBooking),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AdminProvider>().cancel(appointment.id);
    } on BookingException catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AdminProvider>();
    final appointments = provider.appointments;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.adminAppointmentsTitle),
        actions: [
          IconButton(
            tooltip: l10n.adminSignOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: AppColors.textSecondary,
            // Signing out flips AdminProvider to signedOut; the gate in
            // AdminApp reactively shows the login screen. Nothing to pop —
            // AdminApp is the admin build's home.
            onPressed: () => context.read<AdminProvider>().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (provider.listState == LoadState.loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.purple),
              );
            }

            if (provider.listState == LoadState.failed) {
              return EmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.adminCouldNotLoad,
                message: messageFor(l10n, provider.listError!),
                action: SizedBox(
                  width: 180,
                  child: OutlineActionButton(
                    label: l10n.retry,
                    icon: Icons.refresh_rounded,
                    onPressed: provider.loadAppointments,
                  ),
                ),
              );
            }

            if (appointments.isEmpty) {
              return EmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.adminNoAppointmentsTitle,
                message: l10n.adminNoAppointmentsMessage,
              );
            }

            return RefreshIndicator(
              color: AppColors.purple,
              onRefresh: provider.loadAppointments,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                itemCount: appointments.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            l10n.adminUpcoming,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${appointments.length}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 12.5,
                                ),
                          ),
                        ],
                      ),
                    );
                  }
                  final appointment = appointments[index - 1];
                  return _AdminAppointmentCard(
                    appointment: appointment,
                    onCancel: () => _confirmCancel(context, appointment),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One row of the salon schedule: when, who, how to reach them, and the service.
class _AdminAppointmentCard extends StatelessWidget {
  const _AdminAppointmentCard({
    required this.appointment,
    required this.onCancel,
  });

  final Appointment appointment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final service = SalonService.byId(appointment.serviceId);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.of(context).fullDate(appointment.start),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.cancelAppointment,
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textTertiary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          Text(
            Fmt.timeRange(appointment.start),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.person_outline,
                  label: l10n.labelName,
                  value: appointment.fullName,
                ),
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: l10n.labelPhone,
                  value: Fmt.phone(appointment.phone),
                ),
                InfoRow(
                  icon: Icons.spa_outlined,
                  label: l10n.labelService,
                  value: service?.name(l10n) ?? l10n.serviceNotSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
