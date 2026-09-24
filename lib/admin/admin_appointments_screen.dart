import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../models/salon_service.dart';
import '../providers/admin_provider.dart';
import '../providers/appointment_provider.dart' show LoadState;
import '../services/booking_exception.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';
import '../providers/catalogue_provider.dart';
import 'admin_book_screen.dart';
import 'admin_closures_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_manage_appointment_sheet.dart';
import 'admin_services_screen.dart';
import 'admin_stats_screen.dart';

/// The salon-wide schedule as a calendar: the admin lands on today, sees a
/// month grid with a marker under every day that has bookings, and taps a day
/// to see that day's appointments below.
///
/// State (visible month, selected day, the month's appointments) lives on
/// [AdminProvider], so this screen stays a plain [StatelessWidget] that reads
/// it and calls back into it.
/// Confirms, then cancels [appointment] as staff. Shared by the day list.
/// Opens the sheet where staff record what was done and how it went, then
/// reloads the month if anything came back changed.
Future<void> _manage(BuildContext context, Appointment appointment) async {
  final provider = context.read<AdminProvider>();
  final changed = await ManageAppointmentSheet.show(context, appointment);
  if (changed == true) await provider.loadMonth(provider.visibleMonth);
}

Future<void> _confirmCancel(
  BuildContext context,
  Appointment appointment,
) async {
  final l10n = AppLocalizations.of(context);
  final fmt = Fmt.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        l10n.cancelAppointmentTitle,
        style: const TextStyle(fontSize: 17),
      ),
      content: Text(
        l10n.adminCancelConfirmBody(
          appointment.fullName,
          fmt.shortDate(appointment.start),
          Fmt.time(appointment.start),
        ),
        style: const TextStyle(fontSize: 13.5, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.keepIt),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05C87)),
          child: Text(l10n.cancelBooking),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<AdminProvider>().cancel(appointment.id);
  } on BookingException catch (failure) {
    // The failure only exists after the await, so the message can only
    // be built here — and only if this screen is still around to show it.
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(messageIn(context, failure))),
    );
  }
}

/// Where the menu can take staff, other than the schedule itself.
enum _AdminDestination { customers, services, closures, stats }

class AdminAppointmentsScreen extends StatelessWidget {
  const AdminAppointmentsScreen({super.key});

  void _open(BuildContext context, _AdminDestination destination) {
    final route = switch (destination) {
      _AdminDestination.customers => AdminCustomersScreen.route(),
      _AdminDestination.services => AdminServicesScreen.route(),
      _AdminDestination.closures => AdminClosuresScreen.route(),
      _AdminDestination.stats => AdminStatsScreen.route(),
    };
    Navigator.of(context).push(route);
  }

  Future<void> _newBooking(BuildContext context, AdminProvider provider) async {
    // Opens on the day the schedule is showing: staff are almost always
    // booking for the day in front of them.
    final created = await Navigator.of(context)
        .push<bool>(AdminBookScreen.route(initialDay: provider.selectedDay));
    if (created == true) await provider.loadMonth(provider.visibleMonth);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final provider = context.watch<AdminProvider>();
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.adminScheduleTitle),
        actions: [
          // Everything that is not today's schedule lives behind one menu:
          // the schedule is what staff open the app for, and the rest is
          // occasional.
          PopupMenuButton<_AdminDestination>(
            tooltip: l10n.adminMenu,
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (destination) => _open(context, destination),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AdminDestination.customers,
                child: Text(l10n.adminCustomers),
              ),
              PopupMenuItem(
                value: _AdminDestination.services,
                child: Text(l10n.adminServices),
              ),
              PopupMenuItem(
                value: _AdminDestination.closures,
                child: Text(l10n.adminClosures),
              ),
              PopupMenuItem(
                value: _AdminDestination.stats,
                child: Text(l10n.adminStats),
              ),
            ],
          ),
          IconButton(
            tooltip: l10n.adminSignOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: AppColors.textSecondary,
            // Signing out flips AdminProvider to signedOut; the gate in
            // AdminApp reactively shows the login screen. Nothing to pop —
            // AdminApp is the admin build's home.
            onPressed: () => context.read<AdminProvider>().signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newBooking(context, provider),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(l10n.adminNewBooking),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // --- Calendar (fixed at the top) ------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: SoftCard(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                child: Column(
                  children: [
                    _MonthHeader(
                      label: fmt.monthYear(provider.visibleMonth),
                      onPrevious: () => provider.showMonth(-1),
                      onNext: () => provider.showMonth(1),
                    ),
                    const SizedBox(height: 14),
                    _WeekdayRow(labels: fmt.weekdayLabels()),
                    const SizedBox(height: 6),
                    _AdminMonthGrid(
                      month: provider.visibleMonth,
                      today: today,
                      selected: provider.selectedDay,
                      markedDays: provider.daysWithAppointments,
                      onSelect: provider.selectDay,
                    ),
                  ],
                ),
              ),
            ),

            // --- The selected day's appointments --------------------------
            Expanded(child: _DayPanel(today: today)),
          ],
        ),
      ),
    );
  }
}

/// Everything below the calendar: the selected day's heading and its
/// appointments, plus the month's loading / failed states.
class _DayPanel extends StatelessWidget {
  const _DayPanel({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final provider = context.watch<AdminProvider>();

    if (provider.listState == LoadState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.purple),
      );
    }

    if (provider.listState == LoadState.failed) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: l10n.adminCouldNotLoad,
        message: messageIn(context, provider.listError!),
        action: SizedBox(
          width: 180,
          child: OutlineActionButton(
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            onPressed: () => provider.loadMonth(provider.visibleMonth),
          ),
        ),
      );
    }

    final appointments = provider.selectedDayAppointments;
    final isToday = isSameDay(provider.selectedDay, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected-day heading: the date, "Today" when it is, and a count.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isToday
                      ? '${l10n.adminToday} · ${fmt.fullDate(provider.selectedDay)}'
                      : fmt.fullDate(provider.selectedDay),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: l10n.adminDayAppointmentCount(appointments.length),
              ),
            ],
          ),
        ),
        Expanded(
          child: appointments.isEmpty
              ? _EmptyDay(message: l10n.adminNoAppointmentsOnDay)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _AdminAppointmentCard(
                    appointment: appointments[index],
                    onCancel: () =>
                        _confirmCancel(context, appointments[index]),
                    onManage: () => _manage(context, appointments[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// A soft, centred note when the chosen day has no bookings.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

/// "‹  September 2026  ›" — the admin can page to any month, past or future.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ArrowButton(icon: Icons.chevron_left_rounded, onPressed: onPrevious),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        _ArrowButton(icon: Icons.chevron_right_rounded, onPressed: onNext),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: AppColors.textPrimary,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }
}

/// Monday-first column captions, in the active language.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The month's day cells, each marked with a dot when it has appointments.
/// Unlike the customer calendar, past days are selectable — staff review them.
class _AdminMonthGrid extends StatelessWidget {
  const _AdminMonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.markedDays,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    // DateTime.weekday is 1 = Monday, so the lead-in blank count is weekday - 1.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cellCount = leadingBlanks + daysInMonth;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();

        final day = index - leadingBlanks + 1;
        final date = DateTime(month.year, month.month, day);

        return _AdminDayCell(
          day: day,
          isSelected: isSameDay(date, selected),
          isToday: isSameDay(date, today),
          hasAppointments: markedDays.contains(date),
          onTap: () => onSelect(date),
        );
      },
    );
  }
}

class _AdminDayCell extends StatelessWidget {
  const _AdminDayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.hasAppointments,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool hasAppointments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected ? Colors.white : AppColors.textPrimary;

    // Same 34x34 geometry as the customer calendar's day cell, so it can never
    // overflow the square grid tile. The booked-day marker is a small badge
    // dot inside the circle, below the number — Stack, so there is no vertical
    // flex that could overflow by a pixel on a narrow screen.
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isSelected ? AppColors.primaryGradient : null,
            // Today is ringed, so it still reads when another day is selected.
            border: isToday && !isSelected
                ? Border.all(
                    color: AppColors.purple.withValues(alpha: 0.45),
                    width: 1.2,
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              if (hasAppointments)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // White on the selected day's purple fill; pink otherwise.
                      color: isSelected ? Colors.white : AppColors.pink,
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

/// One row of the schedule: when, who, how to reach them, and the service.
class _AdminAppointmentCard extends StatelessWidget {
  const _AdminAppointmentCard({
    required this.appointment,
    required this.onCancel,
    required this.onManage,
  });

  final Appointment appointment;
  final VoidCallback onCancel;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final service = context.watch<CatalogueProvider>().byId(
      appointment.mainService?.serviceId,
    );

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.timeRange(appointment.start),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(status: appointment.status),
              IconButton(
                tooltip: l10n.adminMenu,
                onPressed: onManage,
                icon: const Icon(Icons.tune_rounded, size: 18),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                tooltip: l10n.cancelAppointment,
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textTertiary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.person_outline,
                  label: l10n.labelName,
                  value: appointment.fullName,
                ),
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: l10n.labelPhone,
                  value: Fmt.phone(appointment.phone),
                ),
                InfoRow(
                  icon: Icons.spa_outlined,
                  label: l10n.labelService,
                  value:
                      service?.localisedName(context) ??
                      l10n.serviceNotSelected,
                ),
                if (appointment.total > 0)
                  InfoRow(
                    icon: Icons.payments_outlined,
                    label: l10n.appointmentTotal,
                    value: '${appointment.total.round()} TL',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How a booking went, at a glance. Confirmed is the ordinary case and says
/// nothing; the others are the ones worth noticing on a busy day.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == AppointmentStatus.confirmed) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      AppointmentStatus.completed => (l10n.statusCompleted, AppColors.purple),
      AppointmentStatus.noShow => (l10n.statusNoShow, AppColors.textSecondary),
      _ => (l10n.statusCancelled, AppColors.textTertiary),
    };

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
