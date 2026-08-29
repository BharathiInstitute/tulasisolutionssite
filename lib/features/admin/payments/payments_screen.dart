import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  PaymentStatus? _selectedStatus;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/payments',
      title: 'Payments',
      actions: [
        IconButton(
          tooltip: 'Refresh payments',
          onPressed: () => ref.invalidate(paymentsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordPaymentDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Record payment'),
      ),
      body: paymentsAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading payments: $error'),
        data: (payments) {
          final filteredPayments = payments.where((payment) {
            if (_selectedStatus != null && payment.status != _selectedStatus) {
              return false;
            }
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return payment.clientName.toLowerCase().contains(query) ||
                payment.transactionId.toLowerCase().contains(query) ||
                payment.paymentMethod.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search client, transaction ID, or method...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.trim());
                      },
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            avatar: const Icon(Icons.list_alt, size: 18),
                            label: Text('All (${payments.length})'),
                            selected: _selectedStatus == null,
                            onSelected: (_) {
                              setState(() => _selectedStatus = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ...PaymentStatus.values.map((status) {
                            final count = payments
                                .where((payment) => payment.status == status)
                                .length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Icon(
                                  _statusIcon(status),
                                  size: 18,
                                  color: _statusColor(status),
                                ),
                                label: Text('${status.displayName} ($count)'),
                                selected: _selectedStatus == status,
                                onSelected: (_) {
                                  setState(() => _selectedStatus = status);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredPayments.isEmpty
                    ? _EmptyPaymentsView(hasPayments: payments.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: filteredPayments.length,
                        itemBuilder: (context, index) => _PaymentCard(
                          payment: filteredPayments[index],
                          onSendUpiLink: () =>
                              _copyUpiMessage(filteredPayments[index]),
                          onVerify: () =>
                              _verifyPayment(filteredPayments[index]),
                          onReject: () =>
                              _rejectPayment(filteredPayments[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(BuildContext context) async {
    final clients = await ref.read(clientsListProvider.future);
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _RecordPaymentDialog(clients: clients),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Payment recorded as pending.')),
      );
    }
  }

  Future<void> _verifyPayment(PaymentRecord payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify payment?'),
        content: Text(
          'Confirm ${_formatAmount(payment.amount)} from '
          '${payment.clientName} as received.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Verify'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _reviewPayment(payment.id, PaymentStatus.verified);
  }

  Future<void> _copyUpiMessage(PaymentRecord payment) async {
    try {
      final client = await ref
          .read(firestoreServiceProvider)
          .getClient(payment.clientId);
      if (client == null) throw Exception('Client record not found');

      final recipientName = client.ownerName?.trim().isNotEmpty == true
          ? client.ownerName!.trim()
          : client.name;
      final message = _buildPaymentMessage(payment, recipientName);
      final upiLink = _buildUpiLink(payment);
      if (!mounted) return;
      final copyType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('UPI payment message'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message prepared for $recipientName. Nothing will be sent '
                  'automatically.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 330),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(child: SelectableText(message)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'link'),
              icon: const Icon(Icons.link),
              label: const Text('Copy link'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'message'),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy message'),
            ),
          ],
        ),
      );
      if (copyType == null) return;

      await Clipboard.setData(
        ClipboardData(text: copyType == 'link' ? upiLink : message),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copyType == 'link'
                ? 'UPI payment link copied.'
                : 'UPI payment message copied.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not copy payment details: $error')),
      );
    }
  }

  Future<void> _rejectPayment(PaymentRecord payment) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject payment?'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Example: Transaction not found',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    await _reviewPayment(
      payment.id,
      PaymentStatus.rejected,
      rejectionReason: reason,
    );
  }

  Future<void> _reviewPayment(
    String paymentId,
    PaymentStatus status, {
    String? rejectionReason,
  }) async {
    try {
      await ref
          .read(firestoreServiceProvider)
          .reviewPayment(
            paymentId: paymentId,
            status: status,
            rejectionReason: rejectionReason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment ${status.name}.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not review payment: $error')),
      );
    }
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentRecord payment;
  final VoidCallback onSendUpiLink;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  const _PaymentCard({
    required this.payment,
    required this.onSendUpiLink,
    required this.onVerify,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final paymentDetails = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(
                    payment.status,
                  ).withValues(alpha: 0.14),
                  foregroundColor: _statusColor(payment.status),
                  child: Icon(_statusIcon(payment.status)),
                ),
                const SizedBox(width: 14),
                Expanded(child: _buildDetails(context)),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  paymentDetails,
                  if (payment.status == PaymentStatus.pending) ...[
                    const SizedBox(height: 14),
                    _buildActions(horizontal: true),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: paymentDetails),
                if (payment.status == PaymentStatus.pending) ...[
                  const SizedBox(width: 12),
                  _buildActions(horizontal: false),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              payment.clientName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                _statusIcon(payment.status),
                size: 16,
                color: _statusColor(payment.status),
              ),
              label: Text(payment.status.displayName),
            ),
            if (payment.status == PaymentStatus.pending)
              ActionChip(
                avatar: const Icon(Icons.link, size: 17),
                label: Text('Copy UPI message'),
                tooltip: 'Copy the UPI payment link or complete message',
                onPressed: onSendUpiLink,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _formatAmount(payment.amount),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 7,
          children: [
            _detail(
              Icons.confirmation_number_outlined,
              'Transaction ID',
              payment.transactionId,
            ),
            if (payment.planName?.trim().isNotEmpty == true)
              _detail(Icons.receipt_long_outlined, 'Plan', payment.planName!),
            _detail(
              Icons.account_balance_wallet_outlined,
              'Method',
              payment.paymentMethod,
            ),
            _detail(
              Icons.event_outlined,
              'Paid',
              _formatDateTime(payment.paymentDate),
            ),
            _detail(
              Icons.schedule_outlined,
              'Recorded',
              _formatDateTime(payment.createdDate),
            ),
          ],
        ),
        if (payment.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text('Notes: ${payment.notes}'),
        ],
        if (payment.requestSentDate != null) ...[
          const SizedBox(height: 8),
          Text(
            'UPI request sent by ${payment.requestSentBy ?? 'Admin'} on '
            '${_formatDateTime(payment.requestSentDate!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (payment.reviewedDate != null) ...[
          const SizedBox(height: 8),
          Text(
            '${payment.status.displayName} by '
            '${payment.reviewedBy ?? 'Admin'} on '
            '${_formatDateTime(payment.reviewedDate!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (payment.rejectionReason?.trim().isNotEmpty == true)
          Text(
            'Reason: ${payment.rejectionReason}',
            style: TextStyle(color: Colors.red.shade700),
          ),
      ],
    );
  }

  Widget _buildActions({required bool horizontal}) {
    final verifyButton = FilledButton.icon(
      onPressed: onVerify,
      icon: const Icon(Icons.verified_outlined),
      label: const Text('Verify'),
    );
    final rejectButton = OutlinedButton.icon(
      onPressed: onReject,
      icon: const Icon(Icons.close),
      label: const Text('Reject'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
    );

    if (horizontal) {
      return Row(
        children: [
          Expanded(child: verifyButton),
          const SizedBox(width: 8),
          Expanded(child: rejectButton),
        ],
      );
    }

    return Column(
      children: [verifyButton, const SizedBox(height: 8), rejectButton],
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    );
  }
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final List<Client> clients;

  const _RecordPaymentDialog({required this.clients});

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _transactionController = TextEditingController();
  final _notesController = TextEditingController();
  String? _clientId;
  Plan? _selectedPlan;
  String _paymentMethod = 'UPI';
  DateTime _paymentDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _transactionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(allPlansStreamProvider);
    final clientPlans =
        plansAsync.valueOrNull
            ?.where((plan) => plan.clientId == _clientId)
            .toList() ??
        [];

    return AlertDialog(
      title: const Text('Record payment'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _clientId,
                  decoration: const InputDecoration(
                    labelText: 'Client',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: widget.clients
                      .map(
                        (client) => DropdownMenuItem(
                          value: client.id,
                          child: Text(client.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _clientId = value;
                      _selectedPlan = null;
                      _amountController.clear();
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Select a client' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('plan-${_clientId ?? 'none'}'),
                  initialValue: _selectedPlan?.id,
                  decoration: InputDecoration(
                    labelText: 'Plan',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    helperText: _clientId == null
                        ? 'Select a client first'
                        : plansAsync.isLoading
                        ? 'Loading assigned plans...'
                        : clientPlans.isEmpty
                        ? 'No plans assigned to this client'
                        : 'Selecting a plan fills its current price',
                  ),
                  items: clientPlans
                      .map(
                        (plan) => DropdownMenuItem(
                          value: plan.id,
                          child: Text(
                            '${plan.name} - ${_formatAmount(plan.price)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _clientId == null || clientPlans.isEmpty
                      ? null
                      : (value) {
                          final plan = clientPlans.firstWhere(
                            (item) => item.id == value,
                          );
                          setState(() {
                            _selectedPlan = plan;
                            _amountController.text = plan.price.toStringAsFixed(
                              2,
                            );
                          });
                        },
                  validator: (_) {
                    if (_clientId == null) return null;
                    if (clientPlans.isEmpty) {
                      return 'Assign a plan to this client first';
                    }
                    return _selectedPlan == null ? 'Select a plan' : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (INR)',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || amount <= 0
                        ? 'Enter a valid amount'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _transactionController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction / reference ID',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the transaction ID'
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: const ['UPI', 'Bank transfer', 'Cash', 'Card', 'Other']
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _paymentMethod = value);
                  },
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Payment date'),
                  subtitle: Text(_formatDate(_paymentDate)),
                  trailing: IconButton(
                    tooltip: 'Choose payment date',
                    onPressed: _pickPaymentDate,
                    icon: const Icon(Icons.edit_calendar_outlined),
                  ),
                ),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save pending'),
        ),
      ],
    );
  }

  Future<void> _pickPaymentDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _paymentDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final client = widget.clients.firstWhere((item) => item.id == _clientId);
    setState(() => _saving = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .createPayment(
            PaymentRecord(
              id: '',
              clientId: client.id,
              clientName: client.name,
              planId: _selectedPlan!.id,
              planName: _selectedPlan!.name,
              amount: double.parse(_amountController.text.trim()),
              transactionId: _transactionController.text.trim(),
              paymentMethod: _paymentMethod,
              paymentDate: _paymentDate,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              createdDate: DateTime.now(),
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record payment: $error')),
      );
    }
  }
}

class _EmptyPaymentsView extends StatelessWidget {
  final bool hasPayments;

  const _EmptyPaymentsView({required this.hasPayments});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPayments ? Icons.filter_alt_off : Icons.payments_outlined,
            size: 52,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          Text(hasPayments ? 'No matching payments' : 'No payments recorded'),
        ],
      ),
    );
  }
}

Color _statusColor(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending:
      return Colors.orange.shade800;
    case PaymentStatus.verified:
      return Colors.green.shade700;
    case PaymentStatus.rejected:
      return Colors.red.shade700;
  }
}

IconData _statusIcon(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending:
      return Icons.hourglass_top_outlined;
    case PaymentStatus.verified:
      return Icons.verified_outlined;
    case PaymentStatus.rejected:
      return Icons.cancel_outlined;
  }
}

String _formatAmount(double amount) => 'INR ${amount.toStringAsFixed(2)}';

String _buildUpiLink(PaymentRecord payment) {
  return Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: {
      'pa': '9666464460-3@ybl',
      'pn': 'Tulasi Solutions',
      'am': payment.amount.toStringAsFixed(2),
      'cu': 'INR',
      'tr': payment.transactionId,
      'tn': 'Payment for ${payment.planName ?? 'Selected plan'}',
    },
  ).toString();
}

String _buildPaymentMessage(PaymentRecord payment, String recipientName) {
  return [
    'Hello $recipientName,',
    '',
    'Payment request from Tulasi Solutions',
    'Plan: ${payment.planName ?? 'Selected plan'}',
    'Amount: ${_formatAmount(payment.amount)}',
    'UPI ID: 9666464460-3@ybl',
    'Reference: ${payment.transactionId}',
    '',
    'Pay securely using this UPI link: ${_buildUpiLink(payment)}',
    '',
    'Please verify the payee name and amount in your UPI app before paying. '
        'After payment, please share the confirmation.',
  ].join('\n');
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_formatDate(local)}, $hour:$minute $period';
}
