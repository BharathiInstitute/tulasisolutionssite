import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tulasisolutionssite/core/chat/chat.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/tasks/sales_record_options.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import '../tasks/tasks_screen.dart';
import '../tasks/sales_record_dialog.dart';
import 'package:tulasisolutionssite/features/chat/lead_transfer.dart';
import 'add_client_screen.dart';
import '../client_profile/client_profile_screen.dart';

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  ClientStage? _selectedStage;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isTransferringLeads = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Client client) => [
    client.clientCode,
    client.name,
    client.ownerName,
    client.category,
    client.contactEmail,
    client.contactPhone,
    client.alternatePhone,
    client.assignedManager,
    client.notes,
    client.followUpNotes,
    client.stage.displayName,
    client.salesProgress,
  ].whereType<String>().join(' ').toLowerCase().contains(_searchQuery);

  Future<void> _transfer(String action, List<Client> clients) async {
    setState(() => _isTransferringLeads = true);
    try {
      if (action == 'import') {
        await importLeadFile(context: context, ref: ref, clients: clients);
      } else {
        await exportLeadFile(context: context, clients: clients);
      }
    } finally {
      if (mounted) setState(() => _isTransferringLeads = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(visibleClientsProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final canReadSales = canReadSalesTasks(profile);
    final plansAsync = canReadSales ? ref.watch(visiblePlansProvider) : null;
    final salesByClient = <String, List<SalesTask>>{
      for (final record in customerSalesRecords(
        clientsAsync.valueOrNull ?? const [],
        plansAsync?.valueOrNull ?? const [],
      ))
        if (!salesTaskIsCompleted(record) && !taskIsArchived(record.plan, record.feature))
          record.plan.clientId: [record],
    };
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/leads',
      title: 'Sales Pipeline',
      actions: [
        if (_isTransferringLeads)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          PopupMenuButton<String>(
            tooltip: 'Import / export leads',
            enabled: clientsAsync.hasValue && !clientsAsync.hasError,
            icon: const Icon(Icons.import_export),
            onSelected: (action) =>
                _transfer(action, clientsAsync.requireValue),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('Import leads')),
              PopupMenuItem(value: 'export', child: Text('Export leads')),
            ],
          ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(clientsListProvider);
            ref.invalidate(taskClientsProvider);
            if (canReadSales) ref.invalidate(allPlansStreamProvider);
          },
        ),
      ],
      body: clientsAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => CustomErrorWidget(
          message: 'Error loading customers: $error',
          onRetry: () => ref.invalidate(clientsListProvider),
        ),
        data: (clients) {
          final scoped = clients.where((client) =>
              (_searchQuery.isEmpty || _matchesSearch(client)) &&
              (_selectedStage == null || client.stage == _selectedStage)).toList();
          final active = scoped.where((client) => !client.isArchived).toList();
          final archived = scoped.where((client) => client.isArchived).toList();
          Widget row(Client client) => ClientCard(
            key: ValueKey(client.id),
            client: client,
            compactSales: true,
            salesTasks: plansAsync?.hasValue == true
                ? salesByClient[client.id] ?? const []
                : null,
            onOpenSalesTasks: canReadSales
                ? () => context.go(
                    Uri(
                      path: '/admin/sales-tasks',
                      queryParameters: {'customer': client.id},
                    ).toString(),
                  )
                : null,
          );
          return Column(
            children: [
              FilterChip(
                label: Text('All (${clients.where((client) => !client.isArchived && (_searchQuery.isEmpty || _matchesSearch(client))).length})'),
                selected: _selectedStage == null,
                onSelected: (_) => setState(() => _selectedStage = null),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by code, name, phone, or details...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(
                        () => _searchQuery = value.trim().toLowerCase(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text('Sale & after: ${clients.where((client) => !client.isArchived && {ClientStage.client, ClientStage.retain, ClientStage.refer}.contains(client.stage)).length}'),
                        Text('Renewals due: ${clients.where((client) => !client.isArchived && client.stage == ClientStage.retain && client.salesProgress == 'Renewal due').length}'),
                        Text('Renewed: ${clients.where((client) => !client.isArchived && client.stage == ClientStage.retain && client.salesProgress == 'Renewed').length}'),
                        Text('Referred leads: ${clients.where((client) => !client.isArchived && client.referredByClientId != null).length}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        spacing: 8,
                        children: [
                          for (final stage in chatFunnelStages)
                            FilterChip(
                              label: Text(
                                '${stage.displayName} (${clients.where((client) => !client.isArchived && client.stage == stage && (_searchQuery.isEmpty || _matchesSearch(client))).length})',
                              ),
                              selected: _selectedStage == stage,
                              onSelected: (_) =>
                                  setState(() => _selectedStage = _selectedStage == stage ? null : stage),
                            ),
                        ],
                      ),
                    ),
                    if (canReadSales && plansAsync!.hasError)
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Sales actions could not be loaded.'),
                          ),
                          IconButton(
                            tooltip: 'Retry sales actions',
                            icon: const Icon(Icons.refresh),
                            onPressed: () =>
                                ref.invalidate(allPlansStreamProvider),
                          ),
                        ],
                      )
                    else if (canReadSales && !plansAsync!.hasValue)
                      const LinearProgressIndicator(),
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 900
                    ? const SizedBox.shrink()
                    : Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('Customer')),
                            Expanded(flex: 2, child: Text('Stage')),
                            Expanded(flex: 4, child: Text('Next action / Due')),
                            SizedBox(width: 336, child: Text('Actions')),
                          ],
                        ),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    if (active.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No customers match these pipeline filters',
                        ),
                      ),
                    ...active.map(row),
                    ExpansionTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: Text('Archived (${archived.length})'),
                      children: [
                        if (archived.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No archived leads in this funnel stage',
                            ),
                          ),
                        ...archived.map(row),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add lead',
        backgroundColor: Colors.green,
        onPressed: () => showAddClientDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SalesContactDialog extends ConsumerStatefulWidget {
  final Client client;

  const SalesContactDialog({super.key, required this.client});

  @override
  ConsumerState<SalesContactDialog> createState() => _SalesContactDialogState();
}

class _SalesContactDialogState extends ConsumerState<SalesContactDialog> {
  final _notes = TextEditingController();
  String _method = 'Call';
  String _outcome = 'Interested';
  late ClientStage _stage;
  bool _schedule = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stage = widget.client.stage;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'Sign in to record contact.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(firestoreServiceProvider)
          .recordSalesContact(
            clientId: widget.client.id,
            method: _method,
            outcome: _outcome,
            notes: _notes.text.trim(),
            recordedBy: profile.uid,
            stage: _stage == widget.client.stage ? null : _stage,
          );
      if (mounted) Navigator.pop(context, (schedule: _schedule, stage: _stage));
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not record contact: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSchedule =
        ref
            .watch(currentUserProfileProvider)
            .valueOrNull
            ?.canAccessPanel('tasks') ==
        true;
    return AlertDialog(
      title: const Text('Log Contact'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.client.name),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Contact method'),
                items: [
                  for (final method in [
                    'Call',
                    'WhatsApp',
                    'Meeting',
                    'Email',
                    'Other',
                  ])
                    DropdownMenuItem(value: method, child: Text(method)),
                ],
                onChanged: _saving
                    ? null
                    : (method) => setState(() => _method = method!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _outcome,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Outcome'),
                items: [
                  for (final outcome in [
                    'Interested',
                    'No answer',
                    'Call back',
                    'Not interested',
                    'Proposal requested',
                    'Proposal accepted',
                    'Payment pending',
                    'Renewal discussed',
                    'Referral received',
                    'Other',
                  ])
                    DropdownMenuItem(value: outcome, child: Text(outcome)),
                ],
                onChanged: _saving
                    ? null
                    : (outcome) => setState(() => _outcome = outcome!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 1000,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ClientStage>(
                initialValue: _stage,
                decoration: const InputDecoration(labelText: 'Sales stage'),
                items: [
                  for (final stage in chatFunnelStages)
                    DropdownMenuItem(
                      value: stage,
                      child: Text(stage.displayName),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (stage) => setState(() => _stage = stage!),
              ),
              if (canSchedule)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Schedule next action'),
                  value: _schedule,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _schedule = value ?? false),
                ),
              if (widget.client.salesContacts.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    'Recent contacts (${widget.client.salesContacts.length})',
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    for (final contact in widget.client.salesContacts.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${contact['method']} - ${contact['outcome']}',
                        ),
                        subtitle: Text(
                          '${contact['at']}\n${contact['notes'] ?? ''}',
                        ),
                      ),
                  ],
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_schedule ? 'Save & Schedule' : 'Save'),
        ),
      ],
    );
  }
}

class ClientCard extends ConsumerWidget {
  final Client client;
  final Plan? plan;
  final VoidCallback? onTap;
  final bool showFollowUpActions;
  final bool showFunnelStage;
  final List<SalesTask>? salesTasks;
  final bool compactSales;
  final VoidCallback? onOpenSalesTasks;

  const ClientCard({
    super.key,
    required this.client,
    this.plan,
    this.onTap,
    this.showFollowUpActions = true,
    this.showFunnelStage = true,
    this.salesTasks,
    this.compactSales = false,
    this.onOpenSalesTasks,
  });

  Color _getStageColor(ClientStage stage) {
    switch (stage) {
      case ClientStage.reach:
        return Colors.orange;
      case ClientStage.click:
        return Colors.deepOrange;
      case ClientStage.register:
        return Colors.blue;
      case ClientStage.consult:
        return Colors.indigo;
      case ClientStage.followUp:
        return Colors.purple;
      case ClientStage.client:
        return Colors.green;
      case ClientStage.retain:
      case ClientStage.refer:
        return Colors.teal;
      case ClientStage.lost:
        return Colors.red;
    }
  }

  Future<void> _changeStage(
    BuildContext context,
    WidgetRef ref,
    ClientStage stage,
  ) async {
    if (stage == client.stage) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateClient(client.copyWith(stage: stage), actor: ref.read(currentUserProfileProvider).valueOrNull);
      ref.invalidate(clientsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${client.name} moved to ${stage.displayName}'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update stage: $error')),
        );
      }
    }
  }

  Future<void> _editClient(BuildContext context, WidgetRef ref) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit client',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ClientDetailsSideSheet(client: client, ref: ref);
      },
    );
    ref.invalidate(clientsListProvider);
  }

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    bool isArchived,
  ) async {
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateClient(client.copyWith(isArchived: isArchived));
      ref.invalidate(clientsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArchived
                  ? '${client.name} archived'
                  : '${client.name} restored to ${client.stage.displayName}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update archive: $error')),
        );
      }
    }
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final notesController = TextEditingController(text: client.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Notes: ${client.name}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: notesController,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Add notes about this client...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save notes'),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await ref
            .read(firestoreServiceProvider)
            .updateClient(client.copyWith(notes: notesController.text.trim()));
        ref.invalidate(clientsListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Notes saved')));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save notes: $error')),
          );
        }
      }
    }
    notesController.dispose();
  }

  Future<void> _deleteLostClient(BuildContext context, WidgetRef ref) async {
    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete lost lead?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are deleting: ${client.name}'),
              const SizedBox(height: 16),
              TextField(
                controller: confirmationController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Type delete to confirm',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: confirmationController,
            builder: (context, value, child) => ElevatedButton(
              onPressed: value.text == 'delete'
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteClient(client.id);
        ref.invalidate(clientsListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${client.name} deleted')));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete client: $error')),
          );
        }
      }
    }
    confirmationController.dispose();
  }

  Future<void> _showFollowUpSettings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          FollowUpSettingsDialog(client: client, ref: ref),
    );
    ref.invalidate(clientsListProvider);
  }

  Future<void> _openWhatsAppChat(BuildContext context, WidgetRef ref) async {
    if (client.doNotContact) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This customer is marked Do not contact.')),
      );
      return;
    }
    final phone = client.contactPhone.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This lead has no WhatsApp phone number.'),
        ),
      );
      return;
    }

    final chat = ref.read(chatProvider);
    final existing = chat.conversations.where(
      (conversation) =>
          conversation.clientId == client.id &&
          conversation.channel == ConversationChannel.whatsapp &&
          (conversation.contactId == client.id ||
              conversation.contactPhone.replaceAll(RegExp(r'\D'), '') ==
                  phone.replaceAll(RegExp(r'\D'), '')),
    );
    final conversation = existing.isNotEmpty
        ? existing.first
        : await chat.createConversation(
            contactId: client.id,
            contactName: client.name,
            contactPhone: phone,
            ownerClientId: client.id,
          );
    if (conversation == null || !context.mounted) return;
    context.push('/admin/chat/${conversation.id}', extra: conversation);
  }

  Future<void> _createSalesTask(
    BuildContext context,
    WidgetRef ref, {
    Client? customer,
  }) async {
    try {
      final List<Plan> plans =
          ref.read(visiblePlansProvider).valueOrNull ??
          (await ref.read(allPlansStreamProvider.future));
      if (!context.mounted) return;
      final taskClient = customer ?? client;
      await showDialog<void>(
        context: context,
        builder: (_) => SalesRecordDialog(
          plans: plans,
          client: taskClient,
          customerRecord: true,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open sales task: $error')),
        );
      }
    }
  }

  Future<void> _logContact(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({bool schedule, ClientStage stage})>(
      context: context,
      builder: (_) => SalesContactDialog(client: client),
    );
    if (result == null) return;
    ref.invalidate(clientsListProvider);
    if (result.schedule && context.mounted) {
      await _createSalesTask(
        context,
        ref,
        customer: client.copyWith(stage: result.stage),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = plan != null ? (plan!.progress * 100).round() : null;
    final nextAction = salesTasks?.firstOrNull;
    final canManageSales =
        ref
            .watch(currentUserProfileProvider)
            .valueOrNull
            ?.canAccessPanel('tasks') ==
        true;

    if (compactSales) {
      return _buildSalesRow(context, ref, nextAction, canManageSales);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        title: Text(client.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (client.clientCode.isNotEmpty)
              _detailLine(Icons.tag_outlined, 'Code', client.clientCode),
            _detailLine(Icons.business, 'Business', client.name),
            if ((client.ownerName ?? client.assignedManager)
                    ?.trim()
                    .isNotEmpty ==
                true)
              _detailLine(
                Icons.person_outline,
                'Owner',
                client.ownerName ?? client.assignedManager!,
              ),
            if (client.contactPhone.trim().isNotEmpty)
              _detailLine(Icons.phone_outlined, 'Phone', client.contactPhone),
            if (client.alternatePhone?.trim().isNotEmpty == true)
              _detailLine(
                Icons.phone_android_outlined,
                'Alternate phone',
                client.alternatePhone!,
              ),
            if (client.contactEmail.trim().isNotEmpty)
              _detailLine(Icons.email_outlined, 'Email', client.contactEmail),
            if (client.category.trim().isNotEmpty)
              _detailLine(Icons.category_outlined, 'Category', client.category),
            _detailLine(
              Icons.schedule_outlined,
              'Created',
              _formatDateTime(client.createdDate),
            ),
            _detailLine(
              Icons.app_registration_outlined,
              'Registration',
              _isRegistered ? 'Registered' : 'Not registered',
            ),
            if (salesTasks != null) ...[
              const SizedBox(height: 6),
              if (nextAction != null) ...[
                _detailLine(
                  Icons.person_outline,
                  'Salesperson',
                  taskAssigneeName(nextAction.plan, nextAction.feature) ??
                      'Unassigned',
                ),
                _detailLine(
                  Icons.checklist_outlined,
                  'Next action',
                  parseFeature(nextAction.feature).text,
                ),
                if (taskDueAt(nextAction.plan, nextAction.feature)
                    case final DateTime due)
                  _detailLine(
                    Icons.event_outlined,
                    due.isBefore(DateTime.now()) ? 'Overdue' : 'Due',
                    _formatDateTime(due),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open sales task'),
                  onPressed:
                      !canManageSales &&
                          !ref
                              .read(currentStaffIdsProvider)
                              .contains(
                                taskAssigneeId(
                                  nextAction.plan,
                                  nextAction.feature,
                                ),
                              )
                      ? null
                      : () async {
                          try {
                            final users = canManageSales
                                ? await ref.read(allUsersProvider.future)
                                : const <AppUser>[];
                            if (!context.mounted) return;
                            await showDialog<void>(
                              context: context,
                              builder: (_) => TaskWorkflowDialog(
                                allowCompletion: false,
                                task: TaskItem(
                                  plan: nextAction.plan,
                                  rawFeature: nextAction.feature,
                                ),
                                clientName: client.name,
                                ref: ref,
                                staff: users,
                                lockedAssigneeId: canManageSales
                                    ? null
                                    : taskAssigneeId(
                                        nextAction.plan,
                                        nextAction.feature,
                                      ),
                                lockedAssigneeName: canManageSales
                                    ? null
                                    : taskAssigneeName(
                                        nextAction.plan,
                                        nextAction.feature,
                                      ),
                              ),
                            );
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not open sales task: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                ),
              ] else ...[
                _detailLine(Icons.person_outline, 'Salesperson', 'Unassigned'),
                _detailLine(
                  Icons.checklist_outlined,
                  'Next action',
                  client.followUpAt != null
                      ? client.followUpNotes ?? 'Follow-up reminder'
                      : 'Not scheduled',
                ),
              ],
            ],
            if (client.salesContacts.lastOrNull
                case final Map<String, dynamic> contact)
              _detailLine(
                Icons.history,
                'Last contact',
                '${contact['method']} - ${contact['outcome']}'
                    '${_formatContactTime(contact)}',
              ),
            if (client.followUpAt != null)
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(minutes: 1),
                  (tick) => tick,
                ),
                builder: (context, snapshot) {
                  final remaining = client.followUpAt!.difference(
                    DateTime.now(),
                  );
                  final overdue = remaining.isNegative;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          overdue
                              ? Icons.warning_amber_outlined
                              : Icons.alarm_outlined,
                          size: 16,
                          color: overdue ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                overdue
                                    ? 'Follow-up overdue by ${_formatCountdown(remaining.abs())}'
                                    : 'Follow-up in ${_formatCountdown(remaining)}',
                                style: TextStyle(
                                  color: overdue ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (client.followUpNotes?.trim().isNotEmpty ==
                                  true)
                                Text(
                                  client.followUpNotes!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (showFunnelStage) ...[
              const SizedBox(height: 4),
              PopupMenuButton<ClientStage>(
                tooltip: 'Change funnel stage',
                onSelected: (stage) => _changeStage(context, ref, stage),
                itemBuilder: (context) => chatFunnelStages
                    .map(
                      (stage) => PopupMenuItem(
                        value: stage,
                        child: Row(
                          children: [
                            Icon(
                              stage == client.stage
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 18,
                              color: _getStageColor(stage),
                            ),
                            const SizedBox(width: 8),
                            Text(stage.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: StageChip(
                  label: client.stage.displayName,
                  backgroundColor: _getStageColor(
                    client.stage,
                  ).withValues(alpha: 0.2),
                  textColor: _getStageColor(client.stage),
                ),
              ),
            ],
            if (plan != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan!.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: plan!.progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              plan!.isCompleted ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(plan!.isCompleted ? 'Completed' : '$percent%'),
                    backgroundColor: plan!.isCompleted
                        ? Colors.green.withValues(alpha: 0.15)
                        : null,
                    labelStyle: TextStyle(
                      color: plan!.isCompleted ? Colors.green : null,
                      fontWeight: plan!.isCompleted ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: showFollowUpActions && MediaQuery.sizeOf(context).width >= 800
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Open WhatsApp chat',
                    icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                    onPressed: () => _openWhatsAppChat(context, ref),
                  ),
                  IconButton(
                    tooltip: 'Follow-up settings',
                    icon: Icon(
                      Icons.alarm_outlined,
                      color: client.followUpAt == null ? null : Colors.green,
                    ),
                    onPressed: () => _showFollowUpSettings(context, ref),
                  ),
                  if (salesTasks != null &&
                      canManageSales &&
                      !client.isArchived)
                    IconButton(
                      tooltip: 'Create sales task',
                      icon: const Icon(Icons.add_task),
                      onPressed: () => _createSalesTask(context, ref),
                    ),
                  if (!client.isArchived)
                    IconButton(
                      tooltip: 'Log contact',
                      icon: const Icon(Icons.phone_callback_outlined),
                      onPressed: () => _logContact(context, ref),
                    ),
                  IconButton(
                    tooltip: 'Add or edit notes',
                    icon: const Icon(Icons.note_add_outlined),
                    onPressed: () => _editNotes(context, ref),
                  ),
                  if (showFunnelStage)
                    IconButton(
                      tooltip: client.isArchived
                          ? 'Restore lead'
                          : 'Archive lead',
                      icon: Icon(
                        client.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      onPressed: () =>
                          _setArchived(context, ref, !client.isArchived),
                    ),
                  if (client.stage == ClientStage.lost)
                    IconButton(
                      tooltip: 'Delete lost lead',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteLostClient(context, ref),
                    ),
                  IconButton(
                    tooltip: 'Edit client details',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editClient(context, ref),
                  ),
                ],
              )
            : showFollowUpActions
            ? PopupMenuButton<String>(
                tooltip: 'Lead actions',
                onSelected: (action) {
                  switch (action) {
                    case 'chat':
                      _openWhatsAppChat(context, ref);
                    case 'reminder':
                      _showFollowUpSettings(context, ref);
                    case 'sales':
                      _createSalesTask(context, ref);
                    case 'contact':
                      _logContact(context, ref);
                    case 'notes':
                      _editNotes(context, ref);
                    case 'archive':
                      _setArchived(context, ref, !client.isArchived);
                    case 'edit':
                      _editClient(context, ref);
                    case 'delete':
                      _deleteLostClient(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'chat',
                    child: Text('Open WhatsApp chat'),
                  ),
                  const PopupMenuItem(
                    value: 'reminder',
                    child: Text('Follow-up settings'),
                  ),
                  if (!client.isArchived)
                    const PopupMenuItem(
                      value: 'contact',
                      child: Text('Log contact'),
                    ),
                  if (salesTasks != null &&
                      canManageSales &&
                      !client.isArchived)
                    const PopupMenuItem(
                      value: 'sales',
                      child: Text('Create sales task'),
                    ),
                  const PopupMenuItem(
                    value: 'notes',
                    child: Text('Add or edit notes'),
                  ),
                  if (showFunnelStage)
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(
                        client.isArchived ? 'Restore lead' : 'Archive lead',
                      ),
                    ),
                  if (client.stage == ClientStage.lost)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete lost lead'),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit client details'),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openSalesWorkflow(
    BuildContext context,
    WidgetRef ref,
    SalesTask task,
  ) async {
    try {
      final List<Plan> plans =
          ref.read(visiblePlansProvider).valueOrNull ??
          (await ref.read(allPlansStreamProvider.future));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            SalesRecordDialog(client: client, plans: plans, initialTask: task, customerRecord: true),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open sales task: $error')),
        );
      }
    }
  }

  Future<void> _showSalesDetails(BuildContext context, WidgetRef ref) async {
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      final canReadTasks = [
        'myDashboard',
        'plans',
        'tasks',
        'myTasks',
      ].any((panel) => profile?.canAccessPanel(panel) == true);
      final List<Plan> plans = canReadTasks
          ? ref.read(visiblePlansProvider).valueOrNull ??
                (await ref.read(allPlansStreamProvider.future))
          : <Plan>[];
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => SalesRecordDialog(client: client, plans: plans, customerRecord: true),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open sales record: $error')),
        );
      }
    }
  }

  Future<void> _callCustomer(BuildContext context) async {
    if (client.doNotContact) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This customer is marked Do not contact.')),
      );
      return;
    }
    final phone = client.contactPhone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return;
    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No phone dialer available');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.')),
        );
      }
    }
  }

  Widget _buildSalesRow(
    BuildContext context,
    WidgetRef ref,
    SalesTask? nextAction,
    bool canManage,
  ) {
    final due = nextAction == null
        ? client.followUpAt
        : taskDueAt(nextAction.plan, nextAction.feature);
    final overdue = due?.isBefore(DateTime.now()) == true;
    final stageColor = _getStageColor(client.stage);
    final action = salesTasks == null
        ? '-'
        : nextAction == null
        ? client.followUpAt == null
              ? '-'
              : client.followUpNotes?.trim().isNotEmpty == true
              ? client.followUpNotes!
              : 'Follow-up reminder'
        : parseFeature(nextAction.feature).text;
    Widget textCell(String text, {TextStyle? style}) =>
        Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    final customer = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        textCell(
          client.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        textCell('Progress: ${salesProgressLabel(client.stage, client.salesProgress)}'),
        if (client.clientCode.isNotEmpty)
          textCell(
            client.clientCode,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (client.contactPhone.trim().isNotEmpty)
          textCell(
            client.contactPhone.trim(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
    final next = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        textCell(action),
        if (due != null)
          textCell(
            '${overdue ? 'Overdue - ' : ''}${_formatDateTime(due)}',
            style: TextStyle(
              color: overdue
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    final stageControl = PopupMenuButton<ClientStage>(
      tooltip: 'Change sales stage',
      onSelected: (stage) => _changeStage(context, ref, stage),
      itemBuilder: (_) => [
        for (final stage in chatFunnelStages)
          PopupMenuItem(value: stage, child: Text(stage.displayName)),
      ],
      child: Row(
        children: [
          Flexible(
            child: StageChip(
              label: client.stage.displayName,
              backgroundColor: stageColor.withValues(alpha: 0.2),
              textColor: stageColor,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      children: [
        IconButton(
          tooltip: 'Call customer',
          icon: const Icon(Icons.call_outlined),
          onPressed: client.contactPhone.replaceAll(RegExp(r'\D'), '').isEmpty
              ? null
              : () => _callCustomer(context),
        ),
        if (canManage && !client.isArchived)
          IconButton(
            tooltip: 'Create sales task',
            icon: const Icon(Icons.add_task_outlined),
            onPressed: salesTasks == null
                ? null
                : () => _createSalesTask(context, ref),
          ),
        if (onOpenSalesTasks != null)
          IconButton(
            tooltip: 'Open sales tasks',
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: onOpenSalesTasks,
          ),
        if (!client.isArchived)
          IconButton(
            tooltip: 'Open sales record',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: nextAction != null
                ? () => _openSalesWorkflow(context, ref, nextAction)
                : () => _showSalesDetails(context, ref),
          ),
        if (ref
                .read(currentUserProfileProvider)
                .valueOrNull
                ?.canAccessPanel('chat') ==
            true)
          IconButton(
            tooltip: 'Open WhatsApp chat',
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => _openWhatsAppChat(context, ref),
          ),
        IconButton(
          tooltip: 'Edit customer',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _editClient(context, ref),
        ),
        IconButton(
          tooltip: client.isArchived ? 'Restore lead' : 'Archive lead',
          icon: Icon(
            client.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
          ),
          onPressed: () => _setArchived(context, ref, !client.isArchived),
        ),
        if (client.stage == ClientStage.lost)
          IconButton(
            tooltip: 'Delete lost lead',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteLostClient(context, ref),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Material(
          color: Color.alphaBlend(
            stageColor.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.surface,
          ),
          child: InkWell(
            onTap: () => _showSalesDetails(context, ref),
            child: Container(
              key: ValueKey('sales-row-${client.id}'),
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: stageColor, width: 3),
                  bottom: BorderSide(color: stageColor.withValues(alpha: 0.25)),
                ),
              ),
              child: desktop
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: customer),
                        Expanded(flex: 2, child: stageControl),
                        Expanded(flex: 4, child: next),
                        SizedBox(width: 336, child: actions),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        customer,
                        const SizedBox(height: 4),
                        Row(children: [Expanded(child: stageControl)]),
                        const SizedBox(height: 4),
                        next,
                        const SizedBox(height: 4),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  String _formatContactTime(Map<String, dynamic> contact) {
    final at = DateTime.tryParse(contact['at']?.toString() ?? '');
    return at == null ? '' : ' - ${_formatDateTime(at)}';
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes == 0 ? 1 : minutes}m';
  }

  bool get _isRegistered =>
      client.name.trim().isNotEmpty &&
      (client.ownerName?.trim().isNotEmpty ?? false) &&
      client.category.trim().isNotEmpty &&
      client.contactEmail.trim().isNotEmpty &&
      client.contactPhone.trim().isNotEmpty &&
      (client.alternatePhone?.trim().isNotEmpty ?? false);

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${local.year}, $hour:$minute $period';
  }
}

class FollowUpSettingsDialog extends StatefulWidget {
  final Client client;
  final WidgetRef ref;

  const FollowUpSettingsDialog({
    super.key,
    required this.client,
    required this.ref,
  });

  @override
  State<FollowUpSettingsDialog> createState() => _FollowUpSettingsDialogState();
}

class _FollowUpSettingsDialogState extends State<FollowUpSettingsDialog> {
  late final TextEditingController _notesController;
  DateTime? _followUpAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _followUpAt = widget.client.followUpAt;
    _notesController = TextEditingController(
      text: widget.client.followUpNotes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month + 2, now.day),
      initialDate: _followUpAt ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _followUpAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_followUpAt!),
    );
    if (time == null) return;
    setState(() {
      _followUpAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _setQuickDate(Duration offset) {
    final date = DateTime.now().add(offset);
    final time = TimeOfDay.now();
    setState(() {
      _followUpAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ref
          .read(firestoreServiceProvider)
          .updateClient(
            widget.client.copyWith(
              followUpAt: _followUpAt,
              followUpNotes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              clearFollowUp: _followUpAt == null,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save follow-up: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _followUpAt == null
        ? 'No follow-up scheduled'
        : '${_followUpAt!.day}/${_followUpAt!.month}/${_followUpAt!.year} at '
              '${_followUpAt!.hour == 0
                  ? 12
                  : _followUpAt!.hour > 12
                  ? _followUpAt!.hour - 12
                  : _followUpAt!.hour}:${_followUpAt!.minute.toString().padLeft(2, '0')} ${_followUpAt!.hour >= 12 ? 'PM' : 'AM'}';
    return AlertDialog(
      title: const Text('Follow-up settings'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(dateLabel),
              subtitle: const Text('Set the reminder day and time'),
              trailing: IconButton(
                tooltip: 'Choose date and time',
                onPressed: _pickDateTime,
                icon: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _setQuickDate(Duration.zero),
                  child: const Text('Today'),
                ),
                OutlinedButton(
                  onPressed: () => _setQuickDate(const Duration(days: 7)),
                  child: const Text('This week'),
                ),
                OutlinedButton(
                  onPressed: () => _setQuickDate(const Duration(days: 30)),
                  child: const Text('This month'),
                ),
                if (_followUpAt != null)
                  TextButton(
                    onPressed: () => setState(() => _followUpAt = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Follow-up notes',
                hintText: 'What should be discussed?',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
