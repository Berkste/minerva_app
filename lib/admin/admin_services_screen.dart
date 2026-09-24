import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/salon_service.dart';
import '../providers/catalogue_provider.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';

/// The salon's own price list.
///
/// Editing here is why the catalogue is rows rather than a constant in Dart:
/// prices change, and nobody should need a release to change one.
///
/// Taking a service off the menu does not touch bookings that used it. Each
/// line item recorded its own amount when it was added, so history keeps the
/// price that was actually charged.
class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AdminServicesScreen());

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  List<SalonService> _services = const [];
  bool _isLoading = true;
  BookingException? _error;

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
      final loaded = await context.read<BookingRepository>().fetchCatalogue();
      if (!mounted) return;
      setState(() {
        _services = loaded;
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

  Future<void> _edit(SalonService service) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditServiceSheet(service: service),
    );

    if (saved == true && mounted) {
      await _load();
      // The customer app reads the same catalogue; a price change should not
      // wait for a restart to show up there.
      if (mounted) await context.read<CatalogueProvider>().load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.adminServices),
      ),
      body: SafeArea(top: false, child: _buildBody(context)),
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

    final treatments = _services
        .where((s) => s.kind == ServiceKind.main)
        .toList();
    final extras = _services.where((s) => s.kind == ServiceKind.extra).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _SectionLabel(l10n.serviceTreatments),
        const SizedBox(height: 10),
        for (final service in treatments) ...[
          _ServiceRow(service: service, onEdit: () => _edit(service)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        _SectionLabel(l10n.serviceExtras),
        const SizedBox(height: 10),
        for (final service in extras) ...[
          _ServiceRow(service: service, onEdit: () => _edit(service)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.onEdit});

  final SalonService service;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.localisedName(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      service.priceLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: service.isRanged
                            ? AppColors.purple
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (service.isRanged) ...[
                      const SizedBox(width: 6),
                      Text(
                        l10n.amountLabel.toLowerCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.editService,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Name and price. Only what the salon actually changes — ids, kinds and sort
/// order are structural and stay where the migration put them.
class _EditServiceSheet extends StatefulWidget {
  const _EditServiceSheet({required this.service});

  final SalonService service;

  @override
  State<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<_EditServiceSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameTr = TextEditingController(
    text: widget.service.nameTr,
  );
  late final TextEditingController _nameEn = TextEditingController(
    text: widget.service.nameEn,
  );
  late final TextEditingController _priceMin = TextEditingController(
    text: widget.service.priceMin.round().toString(),
  );
  late final TextEditingController _priceMax = TextEditingController(
    text: widget.service.priceMax?.round().toString() ?? '',
  );

  bool _isSaving = false;

  @override
  void dispose() {
    _nameTr.dispose();
    _nameEn.dispose();
    _priceMin.dispose();
    _priceMax.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final repository = context.read<BookingRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);

    final max = int.tryParse(_priceMax.text.trim());

    try {
      await repository.saveService(
        SalonService(
          id: widget.service.id,
          kind: widget.service.kind,
          nameTr: _nameTr.text.trim(),
          nameEn: _nameEn.text.trim(),
          descriptionTr: widget.service.descriptionTr,
          descriptionEn: widget.service.descriptionEn,
          priceMin: int.parse(_priceMin.text.trim()),
          priceMax: max,
          currency: widget.service.currency,
          sortOrder: widget.service.sortOrder,
        ),
      );
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

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.editService,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameTr,
              decoration: InputDecoration(labelText: l10n.serviceNameTrLabel),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? l10n.firstNameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameEn,
              decoration: InputDecoration(labelText: l10n.serviceNameEnLabel),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? l10n.firstNameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceMin,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.priceMinLabel),
              validator: (v) {
                final value = int.tryParse(v?.trim() ?? '');
                if (value == null || value < 0) return l10n.phoneInvalid;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceMax,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.priceMaxLabel),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return null;
                final max = int.tryParse(text);
                final min = int.tryParse(_priceMin.text.trim()) ?? 0;
                // A range that runs backwards is a typo, and the database
                // would refuse it anyway.
                if (max == null || max < min) return l10n.phoneInvalid;
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
