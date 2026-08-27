import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/booking_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatting.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'details_screen.dart';

/// Step 2 of 5 — pick a two-hour slot between 10:00 and 20:00.
///
/// Slots that have already passed today, or that are taken by an existing
/// booking, are shown but not selectable.
class TimeScreen extends StatelessWidget {
  const TimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final booking = context.watch<BookingProvider>();
    final appointments = context.watch<AppointmentProvider>();
    final date = booking.date!;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.selectTime),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Center(
                    child: Text(
                      Fmt.of(context).fullDate(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Three columns of slots; a fixed grid keeps the rhythm even
                  // if the salon's hours change later.
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: BookingProvider.availableHours.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.9,
                    ),
                    itemBuilder: (context, index) {
                      final hour = BookingProvider.availableHours[index];
                      final slot =
                          DateTime(date.year, date.month, date.day, hour);

                      final isPast = slot.isBefore(now);
                      final isTaken = appointments.isSlotTaken(slot);

                      return _TimeSlot(
                        label: Fmt.hour(hour),
                        isSelected: booking.hour == hour,
                        isDisabled: isPast || isTaken,
                        disabledReason: isTaken ? l10n.slotBooked : null,
                        onTap: () =>
                            context.read<BookingProvider>().selectHour(hour),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  HintBanner(
                    text: l10n.appointmentDurationHint(
                      kAppointmentDuration.inHours,
                    ),
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: GradientButton(
                label: l10n.continueLabel,
                onPressed: booking.hour == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DetailsScreen(),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable time chip.
class _TimeSlot extends StatelessWidget {
  const _TimeSlot({
    required this.label,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
    this.disabledReason,
  });

  final String label;
  final bool isSelected;
  final bool isDisabled;
  final String? disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected ? null : AppColors.white,
        gradient: isSelected ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? Colors.transparent : AppColors.border,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isDisabled
                            ? AppColors.textTertiary.withValues(alpha: 0.55)
                            : AppColors.textPrimary,
                    // A strike-through makes "unavailable" unmistakable
                    // without relying on colour alone.
                    decoration:
                        isDisabled ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textTertiary,
                  ),
                ),
                if (isDisabled && disabledReason != null)
                  Text(
                    disabledReason!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textTertiary.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
