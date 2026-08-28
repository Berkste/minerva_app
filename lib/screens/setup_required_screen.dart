import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/minerva_logo.dart';

/// Shown when the app was built without Supabase credentials.
///
/// Better than crashing on the first query: it names exactly what is missing.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        // Scrolls rather than clipping on short screens and at large text
        // sizes — this is the screen a developer reads when nothing works, so
        // it must never be the thing that is broken.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MinervaLogo(markSize: 56, titleSize: 24),
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.setupRequiredTitle,
                message: l10n.setupRequiredMessage,
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightPurple.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'flutter run \\\n'
                  '  --dart-define=SUPABASE_URL=... \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=...',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
