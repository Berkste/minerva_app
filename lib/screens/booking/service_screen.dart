import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/salon_service.dart';
import '../../providers/booking_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'review_screen.dart';

/// Step 4 of 5 — the optional treatment choice.
///
/// Skipping is a first-class outcome, so "Continue" is always enabled and a
/// "Skip this step" link sits beside it.
class ServiceScreen extends StatelessWidget {
  const ServiceScreen({super.key});

  void _goToReview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final booking = context.watch<BookingProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.selectServiceOptional),
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
                      l10n.chooseTheServiceYouWant,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0;
                            i < SalonService.catalogue.length;
                            i++) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          _ServiceTile(
                            service: SalonService.catalogue[i],
                            isSelected: booking.serviceId ==
                                SalonService.catalogue[i].id,
                            // Tapping the selected row again clears it, which
                            // is how the user "unpicks" without leaving.
                            onTap: () {
                              final provider = context.read<BookingProvider>();
                              final id = SalonService.catalogue[i].id;
                              provider.selectService(
                                provider.serviceId == id ? null : id,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        context.read<BookingProvider>().selectService(null);
                        _goToReview(context);
                      },
                      child: Text(l10n.skipThisStep),
                    ),
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: GradientButton(
                label: l10n.continueLabel,
                onPressed: () => _goToReview(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the service list: thumbnail, name, price, and a radio marker.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  final SalonService service;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Stands in for the photo thumbnail in the design.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: service.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(service.icon, size: 22, color: AppColors.purple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name(AppLocalizations.of(context)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.priceLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SelectionMark(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled purple check when selected, empty ring otherwise.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSelected ? AppColors.primaryGradient : null,
        border: isSelected
            ? null
            : Border.all(color: AppColors.border, width: 1.6),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}
