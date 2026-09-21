import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/salon_service.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/availability_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/booking_exception.dart';
import '../../theme/app_colors.dart';
import '../../utils/error_messages.dart';
import '../../utils/formatting.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'success_screen.dart';
import 'time_screen.dart';
import '../../providers/catalogue_provider.dart';

/// Step 5 of 5 — everything the user chose, in one place, before it is saved.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  /// Guards against a double tap creating two bookings.
  bool _isSaving = false;

  Future<void> _confirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final booking = context.read<BookingProvider>();
    final appointments = context.read<AppointmentProvider>();
    final availability = context.read<AvailabilityProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    final slot = booking.slot!;

    try {
      // No "is it still free?" check first — that would only widen the window
      // for someone else to slip in. The insert is attempted, and the unique
      // index in the database settles it.
      final appointment = await appointments.book(
        slot: slot,
        firstName: booking.firstName,
        lastName: booking.lastName,
        phone: booking.phone,
        serviceId: booking.serviceId,
      );

      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => SuccessScreen(appointment: appointment),
        ),
      );
    } on SlotTakenException {
      // Someone else committed first. Show the slot as taken and send the
      // customer back to the time grid with that hour cleared.
      if (!mounted) return;
      setState(() => _isSaving = false);

      availability.markTaken(slot);
      messenger.showSnackBar(SnackBar(content: Text(l10n.slotJustTaken)));

      // Leave first, then clear the hour. Clearing it notifies listeners, and
      // this screen is one of them — it must be gone before its slot vanishes.
      // Straight back to the time grid, with the calendar still behind it so
      // the customer can change the day instead if they prefer.
      navigator.popUntil(
        (route) => route.settings.name == TimeScreen.routeName || route.isFirst,
      );
      booking.clearHour();
    } on BookingException catch (failure) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(messageFor(l10n, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final booking = context.watch<BookingProvider>();

    final slot = booking.slot;
    if (slot == null) {
      // The draft lost its slot — the booking was rejected and this screen is
      // on its way out. Render nothing rather than dereference a null slot.
      return const Scaffold(body: SizedBox.shrink());
    }

    final start = slot.start;
    final service = context.watch<CatalogueProvider>().byId(booking.serviceId);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.reviewAndConfirm),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CardSectionTitle(l10n.appointmentDetails),
                        const SizedBox(height: 6),
                        const Divider(),
                        const SizedBox(height: 4),
                        InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: l10n.labelDate,
                          value: fmt.fullDate(start),
                        ),
                        InfoRow(
                          icon: Icons.schedule_outlined,
                          label: l10n.labelTime,
                          value: Fmt.timeRange(start),
                        ),
                        InfoRow(
                          icon: Icons.spa_outlined,
                          label: l10n.labelService,
                          value: service?.localisedName(context) ?? l10n.serviceNotSelected,
                        ),
                        if (service != null)
                          InfoRow(
                            icon: Icons.sell_outlined,
                            label: l10n.labelPrice,
                            value: service.priceLabel,
                          ),
                        InfoRow(
                          icon: Icons.timelapse_outlined,
                          label: l10n.labelDuration,
                          value: fmt.durationLabel(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CardSectionTitle(l10n.yourInformation),
                        const SizedBox(height: 6),
                        const Divider(),
                        const SizedBox(height: 4),
                        InfoRow(
                          icon: Icons.person_outline,
                          label: l10n.labelName,
                          value: '${booking.firstName} ${booking.lastName}',
                        ),
                        InfoRow(
                          icon: Icons.phone_outlined,
                          label: l10n.labelPhone,
                          value: Fmt.phone(booking.phone),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  HintBanner(
                    icon: Icons.info_outline_rounded,
                    text: l10n.reviewEditHint,
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: _isSaving
                  ? const _SavingButton()
                  : GradientButton(
                      label: l10n.confirmAppointment,
                      onPressed: _confirm,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same footprint as [GradientButton] so the bar does not jump while saving.
class _SavingButton extends StatelessWidget {
  const _SavingButton();

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
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
