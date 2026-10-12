import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/providers.dart';
import '../../../core/tasks/task_workflow.dart';
import '../../../core/tasks/sales_record_options.dart';
import '../../../core/widgets/feature_progress_widgets.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/task_tracking_widgets.dart';
import 'sales_record_dialog.dart';
import 'tasks_screen.dart';

class SalesTasksScreen extends ConsumerWidget {
  final String? customerId;

  const SalesTasksScreen({super.key, this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRead = canReadSalesTasks(
      ref.watch(currentUserProfileProvider).valueOrNull,
    );
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/sales-tasks',
      title: 'Sales Tasks',
      actions: [
        if (canRead)
          IconButton(
            tooltip: 'Preview examples',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SalesTasksExampleDialog(),
            ),
          ),
        IconButton(
          tooltip: 'Refresh sales tasks',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(clientsListProvider);
            ref.invalidate(taskClientsProvider);
            if (canRead) ref.invalidate(allPlansStreamProvider);
          },
        ),
      ],
      body: canRead
          ? SalesTasksView(customerId: customerId)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sales task access is required. Ask an admin to enable task access.',
                ),
              ),
            ),
    );
  }
}

class SalesTasksView extends ConsumerStatefulWidget {
  final String? customerId;
  final bool previewOnly;

  const SalesTasksView({super.key, this.customerId, this.previewOnly = false});

  @override
  ConsumerState<SalesTasksView> createState() => _SalesTasksViewState();
}

class _SalesTasksViewState extends ConsumerState<SalesTasksView> {
  SalesTaskQueue _queue = SalesTaskQueue.todayAndOverdue;
  String _search = '';
  bool _myTasksOnly = false;
  String? _assigneeId;
  late String? _customerId = widget.customerId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_customerId != null) _queue = SalesTaskQueue.active;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(SalesTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customerId != oldWidget.customerId) {
      _customerId = widget.customerId;
      _queue = SalesTaskQueue.active;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _retry() {
    ref.invalidate(allPlansStreamProvider);
    ref.invalidate(clientsListProvider);
    ref.invalidate(taskClientsProvider);
  }

  Future<void> _create(List<Client> clients, List<Plan> plans) async {
    final choices = clients.where((client) => !client.isArchived).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    var search = '';
    final customer = await showDialog<Client>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose customer'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: choices.isEmpty
                ? const Center(child: Text('No customers available.'))
                : Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search customers',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setDialogState(
                          () => search = value.trim().toLowerCase(),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final client in choices.where(
                              (client) =>
                                  '${client.name} ${client.clientCode} ${client.contactPhone}'
                                      .toLowerCase()
                                      .contains(search),
                            ))
                              ListTile(
                                title: Text(client.name),
                                subtitle: Text(client.clientCode),
                                onTap: () => Navigator.pop(context, client),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (customer == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SalesRecordDialog(
        client: customer,
        plans: plans,
        customerRecord: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(visiblePlansProvider);
    final clientsAsync = ref.watch(visibleTaskClientsProvider);
    final error = plansAsync.error ?? clientsAsync.error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sales tasks could not be loaded.'),
            TextButton(
              onPressed: _retry,
              child: const Text('Retry sales tasks'),
            ),
          ],
        ),
      );
    }
    if (!plansAsync.hasValue ||
        !clientsAsync.hasValue ||
        (plansAsync.isLoading && plansAsync.isReloading)) {
      return const Center(child: CircularProgressIndicator());
    }
    final plans = plansAsync.requireValue;
    final clients = clientsAsync.requireValue;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final staffIds = ref.watch(currentStaffIdsProvider);
    final assignees = <String, String>{};
    final records = customerSalesRecords(clients, plans);
    for (final task in records) {
      final id = taskAssigneeId(task.plan, task.feature);
      if (id != null) {
        assignees[id] = taskAssigneeName(task.plan, task.feature) ?? id;
      }
    }
    final selectedAssignee = assignees.containsKey(_assigneeId)
        ? _assigneeId
        : null;
    final byId = {for (final client in clients) client.id: client};
    final all = records.where((task) {
      final assignee = taskAssigneeId(task.plan, task.feature);
      if (profile?.isAdmin == true &&
          ((_myTasksOnly && !staffIds.contains(assignee)) ||
              (selectedAssignee != null && assignee != selectedAssignee))) {
        return false;
      }
      if (_customerId != null && task.plan.clientId != _customerId) {
        return false;
      }
      final client = byId[task.plan.clientId];
      return '${client?.name ?? ''} ${client?.clientCode ?? ''} '
              '${task.plan.clientId} ${parseFeature(task.feature).text} '
              '${client?.stage.displayName ?? ''} ${client?.salesProgress ?? ''}'
          .toLowerCase()
          .contains(_search);
    }).toList()..sort(compareSalesTaskDue);
    final now = DateTime.now();
    final visible = all
        .where((task) => matchesSalesTaskQueue(task, _queue, now))
        .toList();
    final archived = all
        .where((task) => taskIsArchived(task.plan, task.feature))
        .toList();
    final canCreate =
        !widget.previewOnly &&
        ref
                .watch(currentUserProfileProvider)
                .valueOrNull
                ?.canAccessPanel('tasks') ==
            true;
    String label(SalesTaskQueue queue) => switch (queue) {
      SalesTaskQueue.todayAndOverdue => 'Today & Overdue',
      SalesTaskQueue.upcoming => 'Upcoming',
      SalesTaskQueue.unscheduled => 'Unscheduled',
      SalesTaskQueue.active => 'All active',
      SalesTaskQueue.completed => 'Completed',
    };
    Widget row(SalesTask task) {
      final client = byId[task.plan.clientId];
      final due = taskDueAt(task.plan, task.feature)?.toLocal();
      final parsed = parseFeature(task.feature);
      final status = salesTaskStatusLabel(task);
      final completed = salesTaskIsCompleted(task);
      final overdue = !completed && due != null && due.isBefore(now);
      final today = !completed && due != null && DateUtils.isSameDay(due, now);
      final background = completed
          ? Colors.green.shade50
          : overdue
          ? Colors.red.shade50
          : today
          ? Colors.amber.shade50
          : Colors.blue.shade50;
      final foreground = overdue ? Colors.red.shade800 : Colors.blue.shade800;
      final action = parseFeatureCategory(parsed.category).subcategory;
      return Card(
        key: ValueKey('sales-task-${task.plan.id}-${task.feature}'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: background,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: Icon(
            completed
                ? Icons.verified
                : switch (action) {
                    'Call' => Icons.call_outlined,
                    'WhatsApp' => Icons.chat_outlined,
                    'Meeting' => Icons.groups_outlined,
                    'Proposal' => Icons.description_outlined,
                    'Payment Follow-up' => Icons.payments_outlined,
                    _ => Icons.assignment_outlined,
                  },
            color: completed ? Colors.green : foreground,
          ),
          title: LayoutBuilder(
            builder: (context, constraints) {
              final customerInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client?.name ?? 'Unknown customer (${task.plan.clientId})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Funnel stage: ${client?.stage.displayName ?? 'Unknown'}',
                  ),
                  Text(
                    'Progress: ${client == null ? 'Not recorded' : salesProgressLabel(client.stage, client.salesProgress)}',
                  ),
                ],
              );
              final currentTask = Column(
                crossAxisAlignment: constraints.maxWidth >= 520
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    completed ? 'Completed task' : 'Current task to do',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    parsed.text,
                    key: ValueKey('sales-current-task-${task.plan.clientId}'),
                    textAlign: constraints.maxWidth >= 520
                        ? TextAlign.right
                        : TextAlign.left,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    customerInfo,
                    const SizedBox(height: 8),
                    currentTask,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: customerInfo),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: currentTask),
                ],
              );
            },
          ),
          subtitle: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                completed && due != null
                    ? 'Due: ${MaterialLocalizations.of(context).formatMediumDate(due)}'
                    : 'Due: ${salesTaskDueLabel(context, due, now)}',
                style: overdue
                    ? TextStyle(color: foreground, fontWeight: FontWeight.w600)
                    : null,
              ),
              Text('Status: $status'),
              if (client?.doNotContact == true)
                const Text(
                  'Do not contact',
                  style: TextStyle(color: Colors.red),
                ),
              if (profile?.isAdmin == true && !_myTasksOnly)
                Text(
                  'Assignee: ${taskAssigneeName(task.plan, task.feature) ?? taskAssigneeId(task.plan, task.feature) ?? 'Not assigned'}',
                ),
            ],
          ),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => client == null
                ? TaskWorkflowDialog(
                    task: TaskItem(rawFeature: task.feature, plan: task.plan),
                    clientName: 'No client linked',
                    ref: ref,
                    staff: ref.read(allUsersProvider).valueOrNull ?? [],
                  )
                : UncontrolledProviderScope(
                    container: ProviderScope.containerOf(context),
                    child: SalesRecordDialog(
                      client: client,
                      plans: plans,
                      initialTask: task,
                      previewOnly: widget.previewOnly,
                      allowDeletion: !widget.previewOnly,
                      customerRecord: true,
                    ),
                  ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_customerId != null)
                    TextButton(
                      onPressed: () => context.go('/admin/sales-tasks'),
                      child: const Text('Show all customers'),
                    ),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search customer, code or task',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  if (profile?.isAdmin == true) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Everyone'),
                          selected: !_myTasksOnly,
                          onSelected: (_) => setState(() {
                            _myTasksOnly = false;
                            _assigneeId = null;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('My tasks'),
                          selected: _myTasksOnly,
                          onSelected: (_) => setState(() {
                            _myTasksOnly = true;
                            _assigneeId = null;
                          }),
                        ),
                        if (!_myTasksOnly)
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('sales-assignee-$selectedAssignee'),
                              initialValue: selectedAssignee,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Assignee',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All assignees'),
                                ),
                                for (final entry in assignees.entries)
                                  DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(
                                      entry.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (id) =>
                                  setState(() => _assigneeId = id),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final queue in SalesTaskQueue.values)
                        ChoiceChip(
                          label: Text(
                            '${label(queue)} (${all.where((task) => matchesSalesTaskQueue(task, queue, now)).length})',
                          ),
                          selected: _queue == queue,
                          onSelected: (_) => setState(() => _queue = queue),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No sales tasks match these filters.'),
                    ),
                  ...visible.map(row),
                  if (archived.isNotEmpty)
                    ExpansionTile(
                      title: Text('Archived tasks (${archived.length})'),
                      children: archived.map(row).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (canCreate)
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton.extended(
                onPressed: () => _create(clients, plans),
                icon: const Icon(Icons.add_task),
                label: const Text('Open customer record'),
              ),
            ),
          ),
      ],
    );
  }
}

class SalesTasksExampleDialog extends StatelessWidget {
  const SalesTasksExampleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final customer = Client(
      id: 'demo-customer',
      name: 'Example Learning Centre',
      clientCode: 'DEMO-001',
      category: 'Education',
      contactEmail: 'example@example.com',
      contactPhone: '+1 202 555 0100',
      stage: ClientStage.click,
      createdDate: now.subtract(const Duration(days: 10)),
      salesContacts: [
        {
          'id': 'demo-contact',
          'method': 'Call',
          'outcome': 'Proposal requested',
          'notes':
              'Interested in a monthly plan. Send pricing before the next call.',
          'recordedBy': 'demo-admin',
          'recordedByName': 'Demo Admin',
          'event': 'Action completed',
          'title': 'Discuss monthly plan',
          'nextTitle': 'Send requested pricing',
          'nextAction': 'WhatsApp',
          'nextReminder': DateTime(
            now.year,
            now.month,
            now.day + 1,
            15,
          ).toIso8601String(),
          'at': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
      ],
    );
    final examples = [
      (
        'Sales / Call: Call about monthly plan',
        now.subtract(const Duration(days: 2)),
        'assigned',
      ),
      (
        'Sales / WhatsApp: Send requested pricing',
        DateTime(now.year, now.month, now.day, 23, 59),
        'assigned',
      ),
      (
        'Sales / Meeting: Discuss the proposal',
        DateTime(now.year, now.month, now.day + 1, 15),
        'started',
      ),
      ('Sales / Referral: Ask for a referral', null, 'assigned'),
      (
        'Sales / Call: Introduction call',
        now.subtract(const Duration(days: 3)),
        'completed',
      ),
      ('Sales / Proposal: Previous proposal', null, 'archived'),
    ];
    final customers = [
      for (var i = 0; i < examples.length; i++)
        customer.copyWith(
          id: 'demo-customer-$i',
          name: i == 0 ? customer.name : 'Example customer ${i + 1}',
        ),
    ];
    final plans = [
      for (var i = 0; i < examples.length; i++)
        Plan(
          id: 'demo-sales-$i',
          clientId: customers[i].id,
          type: PlanType.setup,
          name: 'Sales Tasks',
          price: 0,
          startDate: now,
          features: [examples[i].$1],
          taskWorkflow: {
            examples[i].$1: {
              'assignedTo': i.isEven ? 'demo-admin' : 'demo-staff',
              'assignedToName': i.isEven ? 'Demo Admin' : 'Demo Staff',
              'status': examples[i].$3 == 'archived'
                  ? 'assigned'
                  : examples[i].$3,
              if (examples[i].$3 == 'archived') 'isArchived': true,
              if (examples[i].$2 != null)
                'dueAt': examples[i].$2!.toIso8601String(),
              'internalNotes':
                  'Example only: confirm the customer needs and agree on the next step.',
            },
          },
        ),
    ];
    return Dialog.fullscreen(
      child: ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) async => AppUser(
              uid: 'demo-admin',
              email: '',
              name: 'Demo Admin',
              isAdmin: true,
            ),
          ),
          currentStaffIdsProvider.overrideWithValue(['demo-admin']),
          visiblePlansProvider.overrideWith((ref) => AsyncData(plans)),
          taskClientsProvider.overrideWith((ref) async => customers),
          visibleTaskClientsProvider.overrideWithValue(AsyncData(customers)),
          confirmedSalesClientsProvider.overrideWith((ref) => {}),
        ],
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Sales Tasks - example preview'),
            leading: IconButton(
              tooltip: 'Close example preview',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: const Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Sample data only. Explore filters and open cards; nothing is saved or sent.',
                ),
              ),
              Expanded(child: SalesTasksView(previewOnly: true)),
            ],
          ),
        ),
      ),
    );
  }
}
