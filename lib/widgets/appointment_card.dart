import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/salon_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatting.dart';
import 'common.dart';

/// Summary card for one booking. Shared by the home screen ("My Next
/// Appointment") and the appointments list, so both stay identical.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.title,
    this.isPast = false,
    this.onCancel,
  });

  final Appointment appointment;

  /// Optional caption above the details, e.g. "Upcoming Appointment".
  final String? title;

  /// Past bookings are dimmed and lose their cancel affordance.
  final bool isPast;

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = SalonService.byId(appointment.serviceId);

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
                    Fmt.fullDate(appointment.start),
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
                          service?.name ?? 'Service not selected',
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
                      StatusChip(label: isPast ? 'Completed' : 'Confirmed'),
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
      tooltip: 'Cancel appointment',
    );
  }
}
