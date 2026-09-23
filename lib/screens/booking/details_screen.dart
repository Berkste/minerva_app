import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/booking_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/phone_formatter.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'review_screen.dart';

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
    // Re-mask on the way in, so a number saved in another shape still shows
    // as (555) 555 55 55 when the user steps back to this screen.
    _phone = TextEditingController(
      text: TurkishPhoneInputFormatter.format(
        TurkishPhoneInputFormatter.extractDigits(booking.phone),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // A returning customer should not retype what the salon already knows.
    // This runs again when the record finishes loading, so the prefill still
    // happens if the customer got here before the first fetch came back.
    final customer = Provider.of<AppointmentProvider>(context).customer;
    if (customer == null) return;

    // Straight into the controllers: they are what the form reads, and the
    // booking draft is updated from them on Continue. Writing to the provider
    // here would notify listeners mid-build.
    // Only fill what the customer has not already typed over.
    if (_firstName.text.isEmpty) _firstName.text = customer.firstName;
    if (_lastName.text.isEmpty) _lastName.text = customer.lastName ?? '';
    if (_phone.text.isEmpty) {
      _phone.text = TurkishPhoneInputFormatter.format(
        TurkishPhoneInputFormatter.extractDigits(customer.phone),
      );
    }
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
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.yourDetails),
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
                        l10n.pleaseEnterYourInformation,
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
                      decoration: InputDecoration(
                        labelText: l10n.firstName,
                        prefixIcon: const Icon(Icons.person_outline, size: 19),
                      ),
                      validator: (value) => _validateName(
                        value,
                        required: l10n.firstNameRequired,
                        tooShort: l10n.firstNameTooShort,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.lastNameOptional,
                        prefixIcon: const Icon(Icons.person_outline, size: 19),
                      ),
                      // Optional: only a first name and a phone number are
                      // needed to book, and the database agrees — last_name is
                      // nullable. Still checked for length if it is filled in,
                      // because a one-letter surname is a typo either way.
                      validator: (value) => _validateOptionalName(
                        value,
                        tooShort: l10n.lastNameTooShort,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _continue(),
                      // Rewrites the field as (555) 555 55 55 on every
                      // keystroke, so the format cannot be typed wrong.
                      inputFormatters: const [TurkishPhoneInputFormatter()],
                      decoration: InputDecoration(
                        labelText: l10n.phoneNumber,
                        hintText: l10n.phoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined, size: 19),
                      ),
                      validator: (value) => _validatePhone(
                        value,
                        required: l10n.phoneRequired,
                        invalid: l10n.phoneInvalid,
                      ),
                    ),
                    const SizedBox(height: 22),
                    HintBanner(
                      icon: Icons.lock_outline_rounded,
                      text: l10n.detailsPrivacyNote,
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              child: GradientButton(
                label: l10n.continueLabel,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Names must be present and at least two characters.
  static String? _validateName(
    String? value, {
    required String required,
    required String tooShort,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required;
    if (text.length < 2) return tooShort;
    return null;
  }

  /// The surname may be left out entirely, but not left half-typed.
  static String? _validateOptionalName(
    String? value, {
    required String tooShort,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length < 2) return tooShort;
    return null;
  }

  /// Requires a complete 10-digit number, i.e. the full (555) 555 55 55 shape.
  static String? _validatePhone(
    String? value, {
    required String required,
    required String invalid,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required;
    if (!TurkishPhoneInputFormatter.isComplete(text)) return invalid;
    return null;
  }
}
