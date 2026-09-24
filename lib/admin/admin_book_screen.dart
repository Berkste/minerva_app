import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/salon_service.dart';
import '../models/slot.dart';
import '../providers/catalogue_provider.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../utils/phone_formatter.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';
import 'admin_hour_chip.dart';

/// Booking on somebody's behalf, from the desk or the phone.
///
/// One screen rather than the customer's five: staff know the day, the hour
/// and the person already, and making them tap through a wizard for something
/// they can say in one sentence would be the wrong shape.
///
/// A phone number the salon has seen before attaches to that person; a new one
/// creates them. Same rule as the customer app, from the other side.
class AdminBookScreen extends StatefulWidget {
  const AdminBookScreen({super.key, this.initialDay});

  /// The day the schedule was showing, so the common case needs no picking.
  final DateTime? initialDay;

  /// Returns true when a booking was created, so the schedule behind it knows
  /// to reload rather than redraw a day that has changed.
  static Route<bool> route({DateTime? initialDay}) => MaterialPageRoute<bool>(
    builder: (_) => AdminBookScreen(initialDay: initialDay),
  );

  @override
  State<AdminBookScreen> createState() => _AdminBookScreenState();
}

class _AdminBookScreenState extends State<AdminBookScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();

  late DateTime _day;
  int? _hour;
  String? _serviceId;

  Set<Slot> _taken = const {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final base = widget.initialDay ?? DateTime.now();
    _day = DateTime(base.year, base.month, base.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDay());
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Which hours are gone. Staff are exempt from the window and from closed
  /// days, but not from a chair being occupied — so this is the one thing the
  /// screen still has to look up.
  Future<void> _loadDay() async {
    try {
      final taken = await context.read<BookingRepository>().fetchBookedSlots(
        _day,
        _day,
      );
      if (!mounted) return;
      setState(() {
        _taken = taken;
        if (_hour != null && taken.contains(Slot(_day, _hour!))) _hour = null;
      });
    } on BookingException {
      // Leave every hour offerable. The insert is what decides, and it will
      // say so precisely if the slot has gone.
      if (!mounted) return;
      setState(() => _taken = const {});
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked == null) return;

    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      _hour = null;
    });
    await _loadDay();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_hour == null) return;

    final repository = context.read<BookingRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    setState(() => _isSaving = true);

    try {
      await repository.adminBook(
        slot: Slot(_day, _hour!),
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: TurkishPhoneInputFormatter.extractDigits(_phone.text),
        serviceId: _serviceId,
      );

      messenger.showSnackBar(SnackBar(content: Text(l10n.newBookingSaved)));
      navigator.pop(true);
    } on BookingException catch (failure) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(messageIn(context, failure))),
      );
      // A lost slot is the likely one; refresh so the grid shows it gone.
      await _loadDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final treatments = context.watch<CatalogueProvider>().treatments;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.adminNewBooking),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    // --- who -------------------------------------------
                    SoftCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _firstName,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: l10n.firstName,
                            ),
                            validator: (v) => (v?.trim().length ?? 0) < 2
                                ? l10n.firstNameTooShort
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lastName,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: l10n.lastNameOptional,
                            ),
                            validator: (v) {
                              final text = v?.trim() ?? '';
                              if (text.isEmpty) return null;
                              return text.length < 2
                                  ? l10n.lastNameTooShort
                                  : null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            inputFormatters: const [
                              TurkishPhoneInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.phoneNumber,
                              hintText: l10n.phoneHint,
                              helperText: l10n.newBookingFor,
                            ),
                            validator: (v) =>
                                TurkishPhoneInputFormatter.extractDigits(
                                      v ?? '',
                                    ).length !=
                                    10
                                ? l10n.phoneInvalid
                                : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // --- when ------------------------------------------
                    SoftCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: _pickDay,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.pickDay,
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 17,
                                ),
                              ),
                              child: Text(fmt.fullDate(_day)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.pickHour,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final hour in Slot.salonHours)
                                AdminHourChip(
                                  label: Fmt.hour(hour),
                                  isSelected: _hour == hour,
                                  isTaken: _taken.contains(Slot(_day, hour)),
                                  onTap: () => setState(() => _hour = hour),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // --- what ------------------------------------------
                    SoftCard(
                      padding: const EdgeInsets.all(18),
                      child: DropdownButtonFormField<String?>(
                        initialValue: _serviceId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.labelService,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.serviceNotSelected),
                          ),
                          for (final service in treatments)
                            DropdownMenuItem(
                              value: service.id,
                              child: Text(
                                '${service.localisedName(context)}  ·  '
                                '${service.priceLabel}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _serviceId = value),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l10n.adminBookingNote,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
                  : GradientButton(
                      label: l10n.save,
                      onPressed: _hour == null ? null : _save,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
