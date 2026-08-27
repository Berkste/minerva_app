import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatting.dart';
import '../widgets/appointment_card.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';
import 'home_screen.dart';

/// Appointments tab: everything booked, upcoming first, past below.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  /// Confirms before removing, since cancelling cannot be undone.
  Future<void> _confirmCancel(
    BuildContext context,
    Appointment appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('Cancel appointment?', style: TextStyle(fontSize: 17)),
        content: Text(
          'Your booking on ${Fmt.shortDate(appointment.start)} at '
          '${Fmt.time(appointment.start)} will be removed.',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05C87)),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AppointmentProvider>().remove(appointment.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AppointmentProvider>();
    final upcoming = provider.upcoming;
    final past = provider.past;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Appointments'),
      ),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.purple),
              );
            }

            if (upcoming.isEmpty && past.isEmpty) {
              return EmptyState(
                icon: Icons.event_note_outlined,
                title: 'No appointments yet',
                message:
                    'Your bookings will appear here once you schedule your '
                    'first visit.',
                action: SizedBox(
                  width: 210,
                  child: GradientButton(
                    label: 'Add New Appointment',
                    icon: Icons.add_rounded,
                    onPressed: () => HomeScreen.startBooking(context),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                if (upcoming.isNotEmpty) ...[
                  _SectionLabel(
                    'Upcoming',
                    count: upcoming.length,
                  ),
                  const SizedBox(height: 12),
                  for (final appointment in upcoming) ...[
                    AppointmentCard(
                      appointment: appointment,
                      title: 'Upcoming Appointment',
                      onCancel: () => _confirmCancel(context, appointment),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),
                ],

                OutlineActionButton(
                  label: 'Add New Appointment',
                  icon: Icons.add_rounded,
                  onPressed: () => HomeScreen.startBooking(context),
                ),

                if (past.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  _SectionLabel('Past', count: past.length),
                  const SizedBox(height: 12),
                  for (final appointment in past) ...[
                    AppointmentCard(
                      appointment: appointment,
                      title: 'Completed Appointment',
                      isPast: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                if (upcoming.isEmpty && past.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Nothing coming up — book your next visit.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Upcoming · 2" style group heading.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
