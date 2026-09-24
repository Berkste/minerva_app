import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';

/// Which period the figures cover.
enum StatsPeriod { thisMonth, lastMonth, thisYear }

/// What the salon did, and what it earned doing it.
///
/// Counted from the bookings themselves rather than from a stored total: the
/// figures are a question asked of the data, not a number somebody has to
/// remember to keep up to date.
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AdminStatsScreen());

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  StatsPeriod _period = StatsPeriod.thisMonth;

  List<Appointment> _appointments = const [];
  bool _isLoading = true;
  BookingException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime, DateTime) get _range {
    final now = DateTime.now();
    return switch (_period) {
      StatsPeriod.thisMonth => (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 0),
      ),
      StatsPeriod.lastMonth => (
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 0),
      ),
      StatsPeriod.thisYear => (
        DateTime(now.year, 1, 1),
        DateTime(now.year, 12, 31),
      ),
    };
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final (from, to) = _range;

    try {
      final loaded = await context
          .read<BookingRepository>()
          .fetchAppointmentsInRange(from, to);
      if (!mounted) return;
      setState(() {
        _appointments = loaded;
        _isLoading = false;
      });
    } on BookingException catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(l10n.adminStats)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: SegmentedButton<StatsPeriod>(
                segments: [
                  ButtonSegment(
                    value: StatsPeriod.thisMonth,
                    label: Text(l10n.statsThisMonth),
                  ),
                  ButtonSegment(
                    value: StatsPeriod.lastMonth,
                    label: Text(l10n.statsLastMonth),
                  ),
                  ButtonSegment(
                    value: StatsPeriod.thisYear,
                    label: Text(l10n.statsThisYear),
                  ),
                ],
                selected: {_period},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _period = selection.first);
                  _load();
                },
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }

    final error = _error;
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: l10n.somethingWentWrong,
        message: messageIn(context, error),
        action: SizedBox(
          width: 180,
          child: OutlineActionButton(
            label: l10n.retry,
            icon: Icons.refresh_rounded,
            onPressed: _load,
          ),
        ),
      );
    }

    if (_appointments.isEmpty) {
      return EmptyState(
        icon: Icons.insights_outlined,
        title: l10n.statsEmpty,
        message: l10n.statsRevenueNote,
      );
    }

    // fetchAppointmentsInRange leaves cancellations out — they are not part of
    // the schedule any more — so the cancelled count here is only what staff
    // marked no-show. Both are shown so a quiet month reads as a quiet month
    // rather than a broken query.
    final now = DateTime.now();
    final done = _appointments.where((a) => a.didHappen(now: now)).toList();
    final noShows = _appointments
        .where((a) => a.status == AppointmentStatus.noShow)
        .toList();
    final revenue = done.fold<num>(0, (sum, a) => sum + a.total);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        _StatTile(
          label: l10n.statsRevenue,
          value: '${_money(revenue)} TL',
          emphasis: true,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: l10n.statsCompleted,
                value: '${done.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: l10n.statsNoShow,
                value: '${noShows.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.statsRevenueNote,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Turkish thousands separator, no decimals — prices are whole lira.
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: emphasis ? 28 : 22,
              fontWeight: FontWeight.w600,
              color: emphasis ? AppColors.purple : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
