import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/booking_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'service_screen.dart';

/// Step 3 of 5 — who the appointment is for.
class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the draft so going back and forth never loses typing.
    final booking = context.read<BookingProvider>();
    _firstName = TextEditingController(text: booking.firstName);
    _lastName = TextEditingController(text: booking.lastName);
    _phone = TextEditingController(text: booking.phone);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    // Dismiss the keyboard first so the next screen opens on a settled layout.
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    context.read<BookingProvider>().setDetails(
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServiceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Your Details'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Center(
                      child: Text(
                        'Please enter your information',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline, size: 19),
                      ),
                      validator: (value) => _requiredName(value, 'first name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        prefixIcon: Icon(Icons.person_outline, size: 19),
                      ),
                      validator: (value) => _requiredName(value, 'last name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _continue(),
                      // Accept the digits, spaces and + that phone numbers use;
                      // reject everything else at the keystroke.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s()-]'),
                        ),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+90 555 123 45 67',
                        prefixIcon: Icon(Icons.phone_outlined, size: 19),
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 22),
                    const HintBanner(
                      icon: Icons.lock_outline_rounded,
                      text:
                          'Your details stay on this device and are only used '
                          'for this booking.',
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              child: GradientButton(label: 'Continue', onPressed: _continue),
            ),
          ],
        ),
      ),
    );
  }

  /// Names must be present and at least two characters.
  static String? _requiredName(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your $label.';
    if (text.length < 2) return 'That $label looks too short.';
    return null;
  }

  /// Requires at least 10 digits, ignoring spaces and punctuation.
  static String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your phone number.';

    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Please enter a valid phone number.';
    return null;
  }
}
