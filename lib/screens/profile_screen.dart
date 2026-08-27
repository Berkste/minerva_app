import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/appointment_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/minerva_logo.dart';

/// Profile tab.
///
/// The app has no accounts, so this shows the contact details carried by the
/// most recent booking plus the salon's own information.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AppointmentProvider>();

    // Most recently created booking is the best guess at "who is using this
    // phone", and it is the only customer data the app holds.
    final latest =
        provider.appointments.isEmpty ? null : provider.appointments.last;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            // --- Identity card -------------------------------------------
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.softGradient,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 28,
                      color: AppColors.purple.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latest?.fullName ?? 'Guest',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          latest?.phone ?? 'Book once to save your details',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Booking stats -------------------------------------------
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Upcoming',
                    value: '${provider.upcoming.length}',
                    icon: Icons.event_available_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Completed',
                    value: '${provider.past.length}',
                    icon: Icons.history_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // --- Salon information ---------------------------------------
            const CardSectionTitle('Salon'),
            const SizedBox(height: 12),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: const [
                  _InfoTile(
                    icon: Icons.schedule_outlined,
                    title: 'Opening hours',
                    subtitle: '10:00 – 22:00, every day',
                  ),
                  Divider(indent: 16, endIndent: 16),
                  _InfoTile(
                    icon: Icons.timelapse_outlined,
                    title: 'Appointment length',
                    subtitle: 'Every booking lasts 2 hours',
                  ),
                  Divider(indent: 16, endIndent: 16),
                  _InfoTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Your data',
                    subtitle: 'Stored on this device only',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 34),
            const Center(child: MinervaLogo(markSize: 40, titleSize: 20)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Version 1.0.0',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact number + caption tile.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.purple),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Static, non-tappable row inside the salon information card.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.purple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
