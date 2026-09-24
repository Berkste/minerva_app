import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/customer.dart';
import '../services/booking_exception.dart';
import '../services/booking_repository.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';
import '../utils/formatting.dart';
import '../utils/phone_formatter.dart';
import '../widgets/common.dart';
import '../widgets/gradient_button.dart';

/// Everyone the salon knows, searchable by name or number.
///
/// The list is this screen's own state rather than a provider: nothing else in
/// the app needs it, and a customer list that outlives the screen showing it is
/// a stale customer list.
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AdminCustomersScreen());

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _search = TextEditingController();

  List<Customer> _customers = const [];
  Set<String> _archivedIds = const {};
  bool _showArchived = false;
  bool _isLoading = true;
  BookingException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repository = context.read<BookingRepository>();

    try {
      // Two passes when archived people are on screen: the archived flag is a
      // timestamp on the row, and the list itself does not carry it — so the
      // difference between the two answers is who is archived.
      final visible = await repository.fetchCustomers(query: _search.text);
      final all = _showArchived
          ? await repository.fetchCustomers(
              query: _search.text,
              includeArchived: true,
            )
          : visible;

      if (!mounted) return;
      final visibleIds = visible.map((c) => c.id).toSet();

      setState(() {
        _customers = all;
        _archivedIds = all
            .map((c) => c.id)
            .where((id) => !visibleIds.contains(id))
            .toSet();
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

  Future<void> _setArchived(Customer customer, bool archived) async {
    final repository = context.read<BookingRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.setCustomerArchived(customer.id, archived);
      await _load();
    } on BookingException catch (failure) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(messageIn(context, failure))),
      );
    }
  }

  Future<void> _edit(Customer customer) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditCustomerSheet(customer: customer),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.adminCustomers),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: l10n.customerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    onPressed: _load,
                  ),
                ),
              ),
            ),
            SwitchListTile(
              value: _showArchived,
              onChanged: (value) {
                setState(() => _showArchived = value);
                _load();
              },
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                l10n.showArchived,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
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

    if (_customers.isEmpty) {
      return Center(
        child: Text(
          l10n.noCustomers,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final customer = _customers[index];
        final isArchived = _archivedIds.contains(customer.id);

        return _CustomerRow(
          customer: customer,
          isArchived: isArchived,
          onEdit: () => _edit(customer),
          onToggleArchive: () => _setArchived(customer, !isArchived),
        );
      },
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.isArchived,
    required this.onEdit,
    required this.onToggleArchive,
  });

  final Customer customer;
  final bool isArchived;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Opacity(
      opacity: isArchived ? 0.55 : 1,
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          customer.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isArchived) ...[
                        const SizedBox(width: 8),
                        _Tag(label: l10n.archivedLabel),
                      ],
                      if (customer.createdByAdmin && !isArchived) ...[
                        const SizedBox(width: 8),
                        _Tag(label: l10n.adminMenu),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.phone(customer.phone),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.editCustomer,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: isArchived ? l10n.restoreCustomer : l10n.archiveCustomer,
              onPressed: onToggleArchive,
              icon: Icon(
                isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                size: 18,
              ),
              color: AppColors.textTertiary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          color: AppColors.purple,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Correcting what the salon holds about somebody — a mistyped number, a
/// surname they gave later.
class _EditCustomerSheet extends StatefulWidget {
  const _EditCustomerSheet({required this.customer});

  final Customer customer;

  @override
  State<_EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends State<_EditCustomerSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName = TextEditingController(
    text: widget.customer.firstName,
  );
  late final TextEditingController _lastName = TextEditingController(
    text: widget.customer.lastName ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: TurkishPhoneInputFormatter.format(widget.customer.phone),
  );

  bool _isSaving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final repository = context.read<BookingRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);

    try {
      await repository.adminUpdateCustomer(
        customerId: widget.customer.id,
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: TurkishPhoneInputFormatter.extractDigits(_phone.text),
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
              l10n.editCustomer,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.firstName),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? l10n.firstNameTooShort
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.lastNameOptional),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                return text.length < 2 ? l10n.lastNameTooShort : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: const [TurkishPhoneInputFormatter()],
              decoration: InputDecoration(
                labelText: l10n.phoneNumber,
                hintText: l10n.phoneHint,
              ),
              validator: (value) =>
                  TurkishPhoneInputFormatter.extractDigits(value ?? '')
                          .length !=
                      10
                  ? l10n.phoneInvalid
                  : null,
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
