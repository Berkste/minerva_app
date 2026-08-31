import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/admin_provider.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';
import '../widgets/minerva_logo.dart';

/// Staff email + password sign-in.
///
/// This is a real authentication boundary, separate from the customer's
/// anonymous flow. Being refused here (wrong password, or a valid account that
/// is not staff) is reported through the same error mapping the rest of the app
/// uses.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await context.read<AdminProvider>().signIn(
          email: _email.text,
          password: _password.text,
        );
    // Success flips the gate to the appointments screen automatically; failure
    // is surfaced below via authError. Nothing else to do here.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AdminProvider>();
    final busy = provider.auth == AdminAuthState.authenticating;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.adminLoginTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              const SizedBox(height: 12),
              const Center(child: MinervaLogo(markSize: 52, titleSize: 22)),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  l10n.adminLoginSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 26),

              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.adminEmail,
                  prefixIcon: const Icon(Icons.mail_outline, size: 19),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.adminEmailRequired : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !busy,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.adminPassword,
                  prefixIcon: const Icon(Icons.lock_outline, size: 19),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? l10n.adminPasswordRequired
                    : null,
              ),

              // Sign-in failures (wrong password, or valid-but-not-staff).
              if (provider.authError != null) ...[
                const SizedBox(height: 16),
                HintBanner(
                  icon: Icons.error_outline_rounded,
                  text: messageFor(l10n, provider.authError!),
                ),
              ],

              const SizedBox(height: 26),
              busy
                  ? const _BusyButton()
                  : GradientButton(
                      label: l10n.adminSignIn,
                      icon: Icons.login_rounded,
                      onPressed: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Matches [GradientButton]'s footprint while signing in.
class _BusyButton extends StatelessWidget {
  const _BusyButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
        ),
      ),
    );
  }
}
