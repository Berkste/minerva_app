import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/salon_service.dart';
import '../providers/appointment_provider.dart';
import '../providers/booking_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/appointment_card.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';
import '../widgets/minerva_logo.dart';
import 'booking/calendar_screen.dart';

/// Landing tab: brand hero, the primary "New Appointment" action, and a
/// preview of whatever the customer has coming up next.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onSeeAllAppointments});

  /// Asks the shell to switch to the Appointments tab.
  final VoidCallback? onSeeAllAppointments;

  /// Clears any half-finished draft, then opens the first booking step.
  static void startBooking(BuildContext context) {
    context.read<BookingProvider>().reset();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CalendarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointments = context.watch<AppointmentProvider>();
    final next = appointments.nextAppointment;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const _HomeHeader(),
            const SizedBox(height: 18),
            const _HeroBanner(),
            const SizedBox(height: 18),
            GradientButton(
              label: 'New Appointment',
              icon: Icons.add_rounded,
              onPressed: () => startBooking(context),
            ),
            const SizedBox(height: 26),

            // --- Next appointment ------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My Next Appointment',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (next != null && onSeeAllAppointments != null)
                  TextButton(
                    onPressed: onSeeAllAppointments,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('See all', style: TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (appointments.isLoading)
              const _CardPlaceholder()
            else if (next == null)
              const _NoUpcomingCard()
            else
              AppointmentCard(appointment: next),

            const SizedBox(height: 26),

            // --- Service catalogue preview ---------------------------------
            Text(
              'Our Services',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const _ServiceStrip(),
          ],
        ),
      ),
    );
  }
}

/// Small logo lockup plus greeting, sitting where an app bar would.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        const MinervaMark(size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MINERVA',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.6,
                  color: AppColors.purple,
                  height: 1.1,
                ),
              ),
              Text(
                'NAIL ART',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  letterSpacing: 3.4,
                  color: AppColors.pink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The pink/purple marketing card at the top of the home screen.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.softGradient),
        child: Stack(
          children: [
            // Decorative bloom in the top-right corner, clipped by the card.
            Positioned(
              right: -34,
              top: -34,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.55),
                      AppColors.pink.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: -10,
              child: Opacity(
                opacity: 0.35,
                child: Icon(
                  Icons.local_florist_rounded,
                  size: 108,
                  color: AppColors.purple.withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Constrained so the headline never runs under the artwork.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your beauty,\nour passion.',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Book your appointment\neasily and quickly.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
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

/// Shown while appointments are still being read from storage.
class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.purple.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// Empty slot where the next appointment would be.
class _NoUpcomingCard extends StatelessWidget {
  const _NoUpcomingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.lightPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              size: 20,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No appointment yet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap "New Appointment" to book your visit.',
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

/// Horizontally scrolling preview of the service catalogue.
class _ServiceStrip extends StatelessWidget {
  const _ServiceStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The strip is a horizontal list, so its height must be fixed — grow it
    // with the user's text size or the two-line service name clips.
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return SizedBox(
      height: 124 * textScale.clamp(1.0, 1.4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: SalonService.catalogue.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final service = SalonService.catalogue[index];
          return SizedBox(
            width: 132,
            child: SoftCard(
              padding: const EdgeInsets.all(12),
              onTap: () => HomeScreen.startBooking(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: service.tint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      service.icon,
                      size: 20,
                      color: AppColors.purple,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        service.priceLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
