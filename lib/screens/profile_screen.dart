import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatting.dart';
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
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AppointmentProvider>();

    // The saved profile, written the first time this device completed a
    // booking. Null means the customer is still a guest.
    final profile = provider.profile;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.profileTitle),
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
                          profile?.fullName ?? l10n.guest,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          profile == null
                              ? l10n.bookOnceToSaveDetails
                              : Fmt.phone(profile.phone),
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
                    label: l10n.statUpcoming,
                    value: '${provider.upcoming.length}',
                    icon: Icons.event_available_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: l10n.statCompleted,
                    value: '${provider.past.length}',
                    icon: Icons.history_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // --- Language ------------------------------------------------
            CardSectionTitle(l10n.language),
            const SizedBox(height: 12),
            const _LanguagePicker(),

            const SizedBox(height: 26),

            // --- Salon information ---------------------------------------
            CardSectionTitle(l10n.salon),
            const SizedBox(height: 12),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.schedule_outlined,
                    title: l10n.openingHours,
                    subtitle: l10n.openingHoursValue,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _InfoTile(
                    icon: Icons.timelapse_outlined,
                    title: l10n.appointmentLength,
                    subtitle: l10n.appointmentLengthValue(
                      kAppointmentDuration.inHours,
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _InfoTile(
                    icon: Icons.lock_outline_rounded,
                    title: l10n.yourData,
                    subtitle: l10n.yourDataValue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 34),
            const Center(child: MinervaLogo(markSize: 40, titleSize: 20)),
            const SizedBox(height: 12),
            Center(
              // Staff use a separate admin build (lib/main_admin.dart); the
              // customer app has no admin entry point at all.
              child: Text(
                l10n.version('1.0.0'),
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

/// Language chooser: device default, Turkish, or English.
///
/// Switching rebuilds the whole app through [LocaleProvider], so the change is
/// visible immediately and remembered for the next launch.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<LocaleProvider>();

    final options = <_LanguageOption>[
      _LanguageOption(label: l10n.languageSystem, locale: null),
      _LanguageOption(label: l10n.languageTurkish, locale: const Locale('tr')),
      _LanguageOption(label: l10n.languageEnglish, locale: const Locale('en')),
    ];

    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            _LanguageTile(
              label: options[i].label,
              isSelected: provider.locale?.languageCode ==
                  options[i].locale?.languageCode,
              onTap: () =>
                  context.read<LocaleProvider>().setLocale(options[i].locale),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({required this.label, required this.locale});

  final String label;
  final Locale? locale;
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.purple
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.purple,
                ),
            ],
          ),
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
