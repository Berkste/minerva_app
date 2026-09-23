import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../models/salon_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatting.dart';
import 'common.dart';
import 'package:provider/provider.dart';
import '../providers/catalogue_provider.dart';

/// Summary card for one booking. Shared by the home screen ("My Next
/// Appointment") and the appointments list, so both stay identical.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.title,
    this.isPast = false,
    this.onCancel,
    this.onChange,
  });

  final Appointment appointment;

  /// Optional caption above the details, e.g. "Upcoming Appointment".
  final String? title;

  /// Past bookings are dimmed and lose their cancel affordance.
  final bool isPast;

  final VoidCallback? onCancel;

  /// Moving the booking to another day or hour. Absent when the salon entered
  /// it, or when it is too close to the hour to change.
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final service = context
        .watch<CatalogueProvider>()
        .byId(appointment.mainService?.serviceId);

    return Opacity(
      opacity: isPast ? 0.6 : 1,
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (onChange != null && !isPast)
                    _CardAction(
                      label: AppLocalizations.of(context).change,
                      onPressed: onChange!,
                    ),
                  if (onCancel != null && !isPast)
                    _CancelButton(onPressed: onCancel!),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Padding(
              padding: EdgeInsets.only(right: title == null ? 0 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.of(context).fullDate(appointment.start),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Fmt.timeRange(appointment.start),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service?.localisedName(context) ?? l10n.serviceNotSelectedOnCard,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: service == null
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                            fontStyle: service == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        label: isPast
                            ? l10n.statusCompleted
                            : l10n.statusConfirmed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon button; asks for confirmation before removing a booking.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded, size: 18),
      color: AppColors.textTertiary,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: AppLocalizations.of(context).cancelAppointment,
    );
  }
}

/// A quiet text action on the card's header row. Deliberately lighter than
/// the cancel button beside it: moving a booking is the reversible one.
class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.purple,
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}
