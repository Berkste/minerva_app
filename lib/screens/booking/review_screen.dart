import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/salon_service.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/booking_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatting.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'success_screen.dart';

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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Someone else may have taken this slot while the user was filling the
    // form; re-check before writing.
    final slot = booking.start!;
    if (appointments.isSlotTaken(slot)) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That slot was just booked. Please pick another time.'),
        ),
      );
      return;
    }

    final appointment = booking.buildAppointment();
    await appointments.add(appointment);

    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => SuccessScreen(appointment: appointment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final start = booking.start!;
    final service = SalonService.byId(booking.serviceId);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Review & Confirm'),
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
                        const CardSectionTitle('Appointment Details'),
                        const SizedBox(height: 6),
                        const Divider(),
                        const SizedBox(height: 4),
                        InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date',
                          value: Fmt.fullDate(start),
                        ),
                        InfoRow(
                          icon: Icons.schedule_outlined,
                          label: 'Time',
                          value: Fmt.timeRange(start),
                        ),
                        InfoRow(
                          icon: Icons.spa_outlined,
                          label: 'Service',
                          value: service?.name ?? 'Not selected',
                        ),
                        if (service != null)
                          InfoRow(
                            icon: Icons.sell_outlined,
                            label: 'Price',
                            value: service.priceLabel,
                          ),
                        InfoRow(
                          icon: Icons.timelapse_outlined,
                          label: 'Duration',
                          value: Fmt.durationLabel(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardSectionTitle('Your Information'),
                        const SizedBox(height: 6),
                        const Divider(),
                        const SizedBox(height: 4),
                        InfoRow(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: '${booking.firstName} ${booking.lastName}',
                        ),
                        InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: booking.phone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const HintBanner(
                    icon: Icons.info_outline_rounded,
                    text: 'Need a change? Tap back to edit any step.',
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: _isSaving
                  ? const _SavingButton()
                  : GradientButton(
                      label: 'Confirm Appointment',
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
