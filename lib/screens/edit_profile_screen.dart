import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/appointment_provider.dart';
import '../services/booking_exception.dart';
import '../utils/error_messages.dart';
import '../utils/phone_formatter.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';

/// Editing the customer's own contact details.
///
/// The same three fields the booking flow asks for, because they are the same
/// three fields — there is no separate registration, so "my details" and "who
/// this booking is for" are one record seen twice.
///
/// Changing them does not rewrite past appointments: each booking keeps the
/// name and number it was made with, so history stays true.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const EditProfileScreen());

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final customer = context.read<AppointmentProvider>().customer;

    _firstName = TextEditingController(text: customer?.firstName ?? '');
    _lastName = TextEditingController(text: customer?.lastName ?? '');
    _phone = TextEditingController(
      text: customer == null ? '' : TurkishPhoneInputFormatter.format(customer.phone),
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<AppointmentProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    setState(() => _isSaving = true);

    try {
      await provider.saveCustomer(
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: TurkishPhoneInputFormatter.extractDigits(_phone.text),
      );

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      navigator.pop();
    } on BookingException catch (failure) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(messageIn(context, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.editProfile),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    SoftCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _firstName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.firstName,
                              prefixIcon:
                                  const Icon(Icons.person_outline, size: 19),
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
                              prefixIcon:
                                  const Icon(Icons.person_outline, size: 19),
                            ),
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
                            onFieldSubmitted: (_) => _save(),
                            inputFormatters: const [
                              TurkishPhoneInputFormatter()
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.phoneNumber,
                              hintText: l10n.phoneHint,
                              prefixIcon:
                                  const Icon(Icons.phone_outlined, size: 19),
                            ),
                            validator: (value) => _validatePhone(
                              value,
                              required: l10n.phoneRequired,
                              invalid: l10n.phoneInvalid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l10n.profilePhoneNote,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              child: _isSaving
                  ? const SavingButton()
                  : GradientButton(label: l10n.save, onPressed: _save),
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

  /// Requires a complete 10-digit number.
  static String? _validatePhone(
    String? value, {
    required String required,
    required String invalid,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required;
    if (TurkishPhoneInputFormatter.extractDigits(text).length != 10) {
      return invalid;
    }
    return null;
  }
}
