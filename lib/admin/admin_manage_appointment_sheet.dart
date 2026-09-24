import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../models/salon_service.dart';
import '../providers/admin_provider.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../models/slot.dart';
import 'admin_hour_chip.dart';

/// Everything staff do to a booking after it exists: record what was done,
/// and say how it went.
///
/// The two halves are separate on purpose. What was done is money — it decides
/// the statistics page — while how it went decides whether the slot and the
/// customer's three weeks are released.
class ManageAppointmentSheet extends StatefulWidget {
  const ManageAppointmentSheet({super.key, required this.appointment});

  final Appointment appointment;

  static Future<bool?> show(BuildContext context, Appointment appointment) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ManageAppointmentSheet(appointment: appointment),
      );

  @override
  State<ManageAppointmentSheet> createState() => _ManageAppointmentSheetState();
}

class _ManageAppointmentSheetState extends State<ManageAppointmentSheet> {
  late Appointment _appointment = widget.appointment;

  List<SalonService> _catalogue = const [];
  bool _isBusy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalogue());
  }

  Future<void> _loadCatalogue() async {
    try {
      final loaded = await context.read<BookingRepository>().fetchCatalogue();
      if (!mounted) return;
      setState(() => _catalogue = loaded);
    } on BookingException {
      // The sheet still works for marking status; only adding a line needs it.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);

    try {
      await action();
      if (!mounted) return;
      await _refresh();
      setState(() {
        _changed = true;
        _isBusy = false;
      });
    } on BookingException catch (failure) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(messageIn(context, failure))),
      );
    }
  }

  /// Re-reads the booking so the lines and the total on screen are the ones in
  /// the database, not an optimistic guess about them.
  Future<void> _refresh() async {
    final repository = context.read<BookingRepository>();
    final day = _appointment.slot.date;
    final all = await repository.fetchAppointmentsInRange(day, day);

    for (final candidate in all) {
      if (candidate.id == _appointment.id) {
        if (mounted) setState(() => _appointment = candidate);
        return;
      }
    }
  }

  Future<void> _setStatus(AppointmentStatus status) async {
    final provider = context.read<AdminProvider>();
    await _run(() => provider.setStatus(_appointment.id, status));
    if (mounted && status == AppointmentStatus.cancelled) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _addLine() async {
    final choice = await showModalBottomSheet<_LineChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddLineSheet(catalogue: _catalogue),
    );
    if (choice == null || !mounted) return;

    final repository = context.read<BookingRepository>();
    await _run(
      () => repository.addLineItem(
        appointmentId: _appointment.id,
        serviceId: choice.serviceId,
        amount: choice.amount,
      ),
    );
  }

  Future<void> _removeLine(String lineId) async {
    final repository = context.read<BookingRepository>();
    await _run(() => repository.removeLineItem(lineId));
  }

  /// Moving a booking, from the salon's side.
  ///
  /// Staff are not held to the customer's hour-before deadline or to the
  /// three-week window — somebody ringing to say they are running late on
  /// Tuesday is exactly the case those rules must not block.
  Future<void> _reschedule() async {
    final slot = await showModalBottomSheet<Slot>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickSlotSheet(current: _appointment.slot),
    );
    if (slot == null || !mounted) return;

    final repository = context.read<BookingRepository>();
    await _run(() => repository.reschedule(_appointment.id, slot));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Whoever opened this wants to know whether anything changed, so the
    // schedule behind it can reload rather than redraw stale numbers.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_appointment.fullName}  ·  ${Fmt.timeRange(_appointment.start)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusLabel(l10n, _appointment.status),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 18),
              _Label(l10n.appointmentServices),
              const SizedBox(height: 8),
              _buildLines(context),

              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isBusy || _catalogue.isEmpty ? null : _addLine,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addExtra),
              ),

              const SizedBox(height: 20),
              _Label(l10n.adminMenu),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed:
                        _isBusy ||
                            _appointment.status == AppointmentStatus.completed
                        ? null
                        : () => _setStatus(AppointmentStatus.completed),
                    child: Text(l10n.markCompleted),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        _isBusy ||
                            _appointment.status == AppointmentStatus.noShow
                        ? null
                        : () => _setStatus(AppointmentStatus.noShow),
                    child: Text(l10n.markNoShow),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Marking a no-show is not only a label: it is what releases this
              // customer from the 21-day window. Whoever presses it should know
              // that before they do, not discover it afterwards.
              Text(
                l10n.markNoShowNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _reschedule,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(l10n.changeAppointment),
              ),

              const SizedBox(height: 18),
              TextButton.icon(
                onPressed:
                    _isBusy ||
                        _appointment.status == AppointmentStatus.cancelled
                    ? null
                    : () => _setStatus(AppointmentStatus.cancelled),
                icon: const Icon(Icons.close_rounded, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                label: Text(l10n.cancelAppointment),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLines(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_appointment.services.isEmpty) {
      return Text(
        l10n.noLineItems,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
      );
    }

    SalonService? lookup(String id) {
      for (final service in _catalogue) {
        if (service.id == id) return service;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in _appointment.services)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lookup(line.serviceId)?.localisedName(context) ??
                        line.serviceId,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13.5),
                  ),
                ),
                Text(
                  '${_money(line.amount)} TL',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (line.id != null)
                  IconButton(
                    tooltip: l10n.removeLine,
                    onPressed: _isBusy ? null : () => _removeLine(line.id!),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: AppColors.textTertiary,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        const Divider(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.appointmentTotal,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13.5),
              ),
            ),
            Text(
              '${_money(_appointment.total)} TL',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ],
    );
  }

  static String _statusLabel(AppLocalizations l10n, AppointmentStatus status) =>
      switch (status) {
        AppointmentStatus.confirmed => l10n.statusConfirmed,
        AppointmentStatus.completed => l10n.statusCompleted,
        AppointmentStatus.cancelled => l10n.statusCancelled,
        AppointmentStatus.noShow => l10n.statusNoShow,
      };

  static String _money(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 10.5,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _LineChoice {
  const _LineChoice(this.serviceId, this.amount);

  final String serviceId;
  final num? amount;
}

/// Picking what was done, and — where the price is a range — what it came to.
class _AddLineSheet extends StatefulWidget {
  const _AddLineSheet({required this.catalogue});

  final List<SalonService> catalogue;

  @override
  State<_AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends State<_AddLineSheet> {
  SalonService? _selected;
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _select(SalonService? service) {
    setState(() {
      _selected = service;
      // A fixed price needs no typing; a range opens with its lower bound so
      // the common case is one tap.
      _amount.text = service == null ? '' : service.priceMin.round().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.addExtra,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SalonService>(
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.labelService),
            items: [
              for (final service in widget.catalogue)
                DropdownMenuItem(
                  value: service,
                  child: Text(
                    '${service.localisedName(context)}  ·  ${service.priceLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _select,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            enabled: selected != null,
            decoration: InputDecoration(
              labelText: l10n.amountLabel,
              suffixText: 'TL',
              helperText: selected?.isRanged == true
                  ? selected!.priceLabel
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: selected == null
                ? null
                : () => Navigator.of(context).pop(
                    _LineChoice(selected.id, int.tryParse(_amount.text.trim())),
                  ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// Picking a new day and hour for an existing booking.
///
/// Only the slot: who the booking is for and what it is for do not change
/// because somebody moved it an hour later.
class _PickSlotSheet extends StatefulWidget {
  const _PickSlotSheet({required this.current});

  final Slot current;

  @override
  State<_PickSlotSheet> createState() => _PickSlotSheetState();
}

class _PickSlotSheetState extends State<_PickSlotSheet> {
  late DateTime _day = widget.current.date;
  late int? _hour = widget.current.hour;

  Set<Slot> _taken = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDay());
  }

  Future<void> _loadDay() async {
    try {
      final taken = await context.read<BookingRepository>().fetchBookedSlots(
        _day,
        _day,
      );
      if (!mounted) return;
      // The booking's own slot is not an obstacle to itself.
      setState(() => _taken = taken.difference({widget.current}));
    } on BookingException {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.changeAppointment,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDay,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.pickDay,
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 17),
              ),
              child: Text(fmt.fullDate(_day)),
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _hour == null
                ? null
                : () => Navigator.of(context).pop(Slot(_day, _hour!)),
            child: Text(l10n.saveChange),
          ),
        ],
      ),
    );
  }
}
