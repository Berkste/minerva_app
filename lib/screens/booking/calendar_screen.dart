import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/booking_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatting.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'time_screen.dart';

/// Step 1 of 5 — pick a day.
///
/// The month grid is built by hand rather than pulled from a package: it is a
/// few dozen lines, and it keeps the visual language identical to the rest of
/// the app.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// First day of the month currently on screen.
  late DateTime _visibleMonth;

  /// Today at midnight — the earliest bookable day.
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    // Open on the month of the date already chosen, if the user is stepping
    // back into this screen; otherwise on the current month.
    final selected = context.read<BookingProvider>().date;
    _visibleMonth = DateTime(
      selected?.year ?? now.year,
      selected?.month ?? now.month,
    );
  }

  /// True when [month] is at or before the current month, i.e. there is nothing
  /// bookable further back.
  bool get _canGoBack => _visibleMonth.isAfter(DateTime(_today.year, _today.month));

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final booking = context.watch<BookingProvider>();
    final selected = booking.date;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.calendarTitle),
        actions: const [
          IconButton(
            onPressed: null,
            icon: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                    child: Column(
                      children: [
                        _MonthHeader(
                          label: fmt.monthYear(_visibleMonth),
                          canGoBack: _canGoBack,
                          onPrevious: () => _shiftMonth(-1),
                          onNext: () => _shiftMonth(1),
                        ),
                        const SizedBox(height: 14),
                        _WeekdayRow(labels: fmt.weekdayLabels()),
                        const SizedBox(height: 6),
                        _MonthGrid(
                          month: _visibleMonth,
                          today: _today,
                          selected: selected,
                          onSelect: (date) =>
                              context.read<BookingProvider>().selectDate(date),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SelectedDateSummary(date: selected),
                ],
              ),
            ),
            BottomActionBar(
              child: GradientButton(
                label: l10n.selectTime,
                // Stays disabled until a day is chosen.
                onPressed: selected == null
                    ? null
                    : () => Navigator.of(context).push(TimeScreen.route()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "‹  Ağustos 2026  ›"
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.canGoBack,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final bool canGoBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          onPressed: canGoBack ? onPrevious : null,
        ),
        // Takes whatever the arrows leave and scales down rather than
        // shoving them off the card — Turkish month names are long, and
        // longer still at large accessibility text sizes.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
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
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: AppColors.textPrimary,
      disabledColor: AppColors.textTertiary.withValues(alpha: 0.4),
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

/// The day cells for one month, padded with blanks so the 1st lands under the
/// correct weekday.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    // DateTime.weekday is 1 = Monday, so the lead-in blank count is weekday - 1.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    // Day 0 of the next month is the last day of this one.
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
        final isPast = date.isBefore(today);

        return _DayCell(
          day: day,
          isSelected: isSameDay(date, selected),
          isToday: isSameDay(date, today),
          isPast: isPast,
          onTap: isPast ? null : () => onSelect(date),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isPast,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool isPast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isPast) {
      textColor = AppColors.textTertiary.withValues(alpha: 0.5);
    } else {
      textColor = AppColors.textPrimary;
    }

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
            // Today is marked with a ring, so it reads even when another day
            // is the selected one.
            border: isToday && !isSelected
                ? Border.all(
                    color: AppColors.purple.withValues(alpha: 0.45),
                    width: 1.2,
                  )
                : null,
          ),
          child: Text(
            '$day',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: textColor,
                  fontWeight:
                      isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ),
      ),
    );
  }
}

/// Footer line echoing the chosen day back to the user.
class _SelectedDateSummary extends StatelessWidget {
  const _SelectedDateSummary({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectedDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            date == null
                ? l10n.pickADayAbove
                : Fmt.of(context).fullDate(date!),
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: date == null ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
