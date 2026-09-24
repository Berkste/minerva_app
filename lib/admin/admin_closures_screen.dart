import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/salon_closure.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';

/// Days the salon has declared shut — a holiday, a day off, a closure.
///
/// Sundays are not here and cannot be added: they are a standing rule in the
/// database, not a decision anyone makes week by week.
class AdminClosuresScreen extends StatefulWidget {
  const AdminClosuresScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AdminClosuresScreen());

  @override
  State<AdminClosuresScreen> createState() => _AdminClosuresScreenState();
}

class _AdminClosuresScreenState extends State<AdminClosuresScreen> {
  List<SalonClosure> _closures = const [];
  bool _isLoading = true;
  BookingException? _error;

  /// A year either side. Closures further out than that are not a thing a
  /// salon plans, and the list stays readable.
  DateTime get _from => DateTime.now().subtract(const Duration(days: 365));
  DateTime get _to => DateTime.now().add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final loaded = await context.read<BookingRepository>().fetchClosures(
        _from,
        _to,
      );
      if (!mounted) return;
      setState(() {
        _closures = loaded;
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

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddClosureSheet(),
    );
    if (added == true) await _load();
  }

  Future<void> _remove(SalonClosure closure) async {
    final repository = context.read<BookingRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      await repository.removeClosure(closure.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.closureRemoved)));
      await _load();
    } on BookingException catch (failure) {
      if (!mounted) return;
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
        title: Text(l10n.adminClosures),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildBody(context)),
            BottomActionBar(
              child: GradientButton(
                label: l10n.closureAdd,
                icon: Icons.event_busy_outlined,
                onPressed: _add,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);

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

    if (_closures.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: l10n.noClosures,
        message: l10n.sundayAlwaysClosed,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: _closures.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final closure = _closures[index];
        final theme = Theme.of(context);

        return SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      closure.isSingleDay
                          ? fmt.fullDate(closure.startDate)
                          : '${fmt.shortDate(closure.startDate)} — '
                                '${fmt.shortDate(closure.endDate)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((closure.reason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        closure.reason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.removeLine,
                onPressed: () => _remove(closure),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textTertiary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddClosureSheet extends StatefulWidget {
  const _AddClosureSheet();

  @override
  State<_AddClosureSheet> createState() => _AddClosureSheetState();
}

class _AddClosureSheetState extends State<_AddClosureSheet> {
  late DateTime _from = _today;
  late DateTime _to = _today;

  final _reason = TextEditingController();
  bool _isSaving = false;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 730)),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = picked;
        // A range that runs backwards is never what somebody meant.
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<void> _save() async {
    final repository = context.read<BookingRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);

    try {
      await repository.addClosure(from: _from, to: _to, reason: _reason.text);
      navigator.pop(true);
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
            l10n.closureAdd,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: l10n.closureFrom,
            value: fmt.fullDate(_from),
            onTap: () => _pick(isFrom: true),
          ),
          const SizedBox(height: 10),
          _DateField(
            label: l10n.closureTo,
            value: fmt.fullDate(_to),
            onTap: () => _pick(isFrom: false),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            decoration: InputDecoration(labelText: l10n.closureReason),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 17),
        ),
        child: Text(value),
      ),
    );
  }
}
