import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../services/booking_exception.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../widgets/appointment_card.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';
import 'home_screen.dart';
import '../providers/booking_provider.dart';
import 'booking/calendar_screen.dart';

/// Appointments tab: everything booked, upcoming first, past below.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  /// Confirms before removing, since cancelling cannot be undone.
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          l10n.cancelAppointmentTitle,
          style: const TextStyle(fontSize: 17),
        ),
        content: Text(
          l10n.cancelAppointmentBody(
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
      await context.read<AppointmentProvider>().cancel(appointment.id);
    } on BookingException catch (failure) {
      // The failure only exists after the await, so the message can only
      // be built here — and only if this screen is still around to show it.
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(messageIn(context, failure))),
      );
    }
  }

  /// Opens the calendar on the booking being moved. The flow from there is the
  /// booking flow: same availability, same rules, same screens.
  void _startReschedule(BuildContext context, Appointment appointment) {
    context.read<BookingProvider>().beginReschedule(appointment);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CalendarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AppointmentProvider>();
    final upcoming = provider.upcoming;
    final past = provider.past;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.myAppointments),
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

            if (provider.state == LoadState.failed) {
              return EmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.couldNotLoadAppointments,
                message: messageIn(context, provider.error!),
                action: SizedBox(
                  width: 180,
                  child: OutlineActionButton(
                    label: l10n.retry,
                    icon: Icons.refresh_rounded,
                    onPressed: () => provider.load(),
                  ),
                ),
              );
            }

            if (upcoming.isEmpty && past.isEmpty) {
              return EmptyState(
                icon: Icons.event_note_outlined,
                title: l10n.noAppointmentsTitle,
                message: l10n.noAppointmentsMessage,
                action: SizedBox(
                  width: 210,
                  child: GradientButton(
                    label: l10n.addNewAppointment,
                    icon: Icons.add_rounded,
                    onPressed: () => HomeScreen.startBooking(context),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.purple,
              onRefresh: provider.load,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                // Says plainly when the list is a cached copy rather than
                // what the server currently holds.
                if (provider.isStale) ...[
                  HintBanner(
                    icon: Icons.cloud_off_rounded,
                    text: l10n.offlineShowingCached,
                  ),
                  const SizedBox(height: 16),
                ],

                if (upcoming.isNotEmpty) ...[
                  _SectionLabel(
                    l10n.sectionUpcoming,
                    count: upcoming.length,
                  ),
                  const SizedBox(height: 12),
                  for (final appointment in upcoming) ...[
                    AppointmentCard(
                      appointment: appointment,
                      title: l10n.upcomingAppointment,
                      // Both are hidden within the hour before the slot, and
                      // for anything the salon booked on the customer's
                      // behalf. The database refuses either case, and offering
                      // a button that cannot work is how you teach somebody
                      // the app is broken.
                      onCancel: appointment.canBeCancelledByCustomer()
                          ? () => _confirmCancel(context, appointment)
                          : null,
                      onChange: appointment.canBeChangedByCustomer()
                          ? () => _startReschedule(context, appointment)
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),
                ],

                OutlineActionButton(
                  label: l10n.addNewAppointment,
                  icon: Icons.add_rounded,
                  onPressed: () => HomeScreen.startBooking(context),
                ),

                if (past.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  _SectionLabel(l10n.sectionPast, count: past.length),
                  const SizedBox(height: 12),
                  for (final appointment in past) ...[
                    AppointmentCard(
                      appointment: appointment,
                      title: l10n.completedAppointment,
                      isPast: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                if (upcoming.isEmpty && past.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      l10n.nothingComingUp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ],
              ),
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
