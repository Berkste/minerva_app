import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/appointment.dart';
import '../../models/slot.dart';
import '../../providers/availability_provider.dart';
import '../../providers/booking_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatting.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'details_screen.dart';

/// Step 2 of 5 — pick a two-hour slot between 10:00 and 20:00.
///
/// Which slots are free is a live question now that bookings are shared, so
/// availability is fetched for the chosen day. If that fetch fails the grid
/// still lets the customer choose and says the choice is unverified — the
/// database has the final say at confirm time regardless.
class TimeScreen extends StatefulWidget {
  const TimeScreen({super.key});

  /// Named so a booking that loses the race can pop straight back here,
  /// keeping the calendar behind it in the stack.
  static const String routeName = 'booking/time';

  static Route<void> route() => MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => const TimeScreen(),
      );

  @override
  State<TimeScreen> createState() => _TimeScreenState();
}

class _TimeScreenState extends State<TimeScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame so the provider can safely notify listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh({bool force = false}) async {
    final date = context.read<BookingProvider>().date;
    if (date == null || !mounted) return;
    await context.read<AvailabilityProvider>().loadFor(date, force: force);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final booking = context.watch<BookingProvider>();
    final availability = context.watch<AvailabilityProvider>();
    final date = booking.date!;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.selectTime),
        actions: [
          IconButton(
            onPressed: availability.isLoading
                ? null
                : () => _refresh(force: true),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppColors.textTertiary,
          ),
        ],
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
                      final slot = Slot(date, hour);

                      final isPast = slot.start.isBefore(now);
                      final isTaken = availability.isTaken(slot);

                      return _TimeSlot(
                        label: Fmt.hour(hour),
                        isSelected: booking.hour == hour,
                        isDisabled: isPast || isTaken,
                        isChecking: availability.isLoading,
                        disabledReason: isTaken ? l10n.slotBooked : null,
                        onTap: () =>
                            context.read<BookingProvider>().selectHour(hour),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  if (availability.isLoading)
                    HintBanner(
                      icon: Icons.sync_rounded,
                      text: l10n.loadingAvailability,
                    )
                  else if (availability.isUnverified)
                    HintBanner(
                      icon: Icons.cloud_off_rounded,
                      text: l10n.availabilityUnavailable,
                    )
                  else
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
    required this.isChecking,
    required this.onTap,
    this.disabledReason,
  });

  final String label;
  final bool isSelected;
  final bool isDisabled;

  /// Availability is still loading, so the chip is dimmed but not struck out.
  final bool isChecking;

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
      child: Opacity(
        opacity: isChecking && !isSelected ? 0.55 : 1,
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
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
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
      ),
    );
  }
}
