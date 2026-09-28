import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';

const _internalPracticeClientId = '__internal_practice__';
const _internalPracticePlanId = '__internal_practice_tasks__';
const _internalPracticeLabel = 'Practice (Internal)';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allPlansStreamProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    final staff = ref.watch(allUsersProvider).valueOrNull ?? const <AppUser>[];
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/tasks',
      title: 'Assign Tasks',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(allPlansStreamProvider),
        ),
      ],
      floatingActionButton: plansAsync.maybeWhen(
        data: (plans) => clientsAsync.maybeWhen(
          data: (clients) => FloatingActionButton.extended(
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (_) => _CustomTaskDialog(
                  plans: plans,
                  clients: clients,
                  staff: staff,
                ),
              );
            },
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Add Task'),
          ),
          orElse: () => null,
        ),
        orElse: () => null,
      ),
      body: plansAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading tasks: $error'),
        data: (plans) => clientsAsync.when(
          loading: () => const LoadingWidget(),
          error: (error, stackTrace) =>
              CustomErrorWidget(message: 'Error loading clients: $error'),
          data: (clients) => _TaskOverview(
            plans: plans,
            staff: staff,
            clientNames: {
              for (final client in clients) client.id: client.name,
            },
          ),
        ),
      ),
    );
  }
}

class _CustomTaskDialog extends ConsumerStatefulWidget {
  final List<Plan> plans;
  final List<Client> clients;
  final List<AppUser> staff;

  const _CustomTaskDialog({
    required this.plans,
    required this.clients,
    required this.staff,
  });

  @override
  ConsumerState<_CustomTaskDialog> createState() => _CustomTaskDialogState();
}

class _CustomTaskDialogState extends ConsumerState<_CustomTaskDialog> {
  final _titleController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _clientId;
  String? _category;
  String? _subcategory;
  String? _assignedTo;
  String _priority = 'normal';
  DateTime? _dueAt;
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Plan? get _selectedPlan {
    if (_clientId == _internalPracticeClientId) {
      return widget.plans
          .where((plan) => plan.id == _internalPracticePlanId)
          .firstOrNull;
    }
    final clientPlans =
        widget.plans.where((plan) => plan.clientId == _clientId).toList()
          ..sort((left, right) => right.startDate.compareTo(left.startDate));
    return clientPlans.firstOrNull;
  }

  bool get _isInternalPractice => _clientId == _internalPracticeClientId;

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  Future<void> _save() async {
    final plan = _selectedPlan;
    final title = _titleController.text.trim();
    final reason = _reasonController.text.trim();
    final subcategories = _category == null
        ? const <String>[]
        : planFeatureSubcategories[_category] ?? const <String>[];
    if (_clientId == null ||
        title.isEmpty ||
        _category == null ||
        (subcategories.isNotEmpty && _subcategory == null) ||
        reason.isEmpty) {
      setState(
        () => _error =
            'Client, title, category, subcategory, and reason are required.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final targetPlan =
          plan ??
          Plan(
            id: _isInternalPractice
                ? _internalPracticePlanId
                : const Uuid().v4(),
            clientId: _clientId!,
            type: PlanType.setup,
            name: _isInternalPractice ? _internalPracticeLabel : 'Custom Tasks',
            price: 0,
            features: const [],
            startDate: DateTime.now(),
          );
      final task = ClientTask(
        id: const Uuid().v4(),
        category: encodeFeatureCategory(_category!, _subcategory),
        title: title,
        order: targetPlan.tasks.length,
        source: ClientTaskSource.customIncluded,
        addedReason: reason,
      );
      final updatedPlan = targetPlan.copyWith(
        features: [...targetPlan.features, task.feature],
        tasks: [...targetPlan.tasks, task],
      );
      final assignedUser = widget.staff
          .where((user) => user.uid == _assignedTo)
          .firstOrNull;
      final assignedPlan = updateTaskAssignment(
        updatedPlan,
        task.feature,
        assignedTo: assignedUser?.uid,
        assignedToName: assignedUser == null
            ? null
            : (assignedUser.name.isEmpty
                  ? assignedUser.email
                  : assignedUser.name),
        priority: _priority,
      );
      final detailedPlan = updateTaskManagementDetails(
        assignedPlan,
        task.feature,
        dueAt: _dueAt,
        internalNotes: reason,
      );
      final service = ref.read(firestoreServiceProvider);
      if (plan == null) {
        await service.createPlan(detailedPlan);
      } else {
        await service.updatePlan(detailedPlan);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not add task: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const taskStages = {
      ClientStage.client,
      ClientStage.retain,
    };
    final taskClients =
        widget.clients
            .where(
              (client) =>
                  taskStages.contains(client.stage) ||
                  widget.plans.any((plan) => plan.clientId == client.id),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    return AlertDialog(
      title: const Text('Task Details'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clientId,
                decoration: const InputDecoration(labelText: 'Client'),
                hint: taskClients.isEmpty
                  ? const Text('No Won or Retain / Refer clients found')
                    : null,
                items:
                    taskClients
                        .map(
                          (client) => DropdownMenuItem(
                            value: client.id,
                            child: Text(client.name),
                          ),
                        )
                        .toList()
                      ..insert(
                        0,
                        const DropdownMenuItem(
                          value: _internalPracticeClientId,
                          child: Text(_internalPracticeLabel),
                        ),
                      ),
                onChanged: (clientId) => setState(() {
                  _clientId = clientId;
                  _category = null;
                  _subcategory = null;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: customTaskFeatureCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (category) => setState(() {
                  _category = category;
                  final options = category == null
                      ? const <String>[]
                      : planFeatureSubcategories[category] ?? const <String>[];
                  _subcategory = options.firstOrNull;
                }),
              ),
              if (_category != null &&
                  (planFeatureSubcategories[_category] ?? const []).isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('create-subcategory-$_category'),
                  initialValue: _subcategory,
                  decoration: const InputDecoration(labelText: 'Subcategory'),
                  items: [
                    for (final subcategory
                        in planFeatureSubcategories[_category]!)
                      DropdownMenuItem(
                        value: subcategory,
                        child: Text(subcategory),
                      ),
                  ],
                  onChanged: (subcategory) =>
                      setState(() => _subcategory = subcategory),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _assignedTo,
                decoration: const InputDecoration(labelText: 'Assigned staff'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Not assigned'),
                  ),
                  for (final user in widget.staff)
                    DropdownMenuItem<String?>(
                      value: user.uid,
                      child: Text(
                        user.name.isEmpty ? user.email : user.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (staffId) => setState(() => _assignedTo = staffId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (value) =>
                    setState(() => _priority = value ?? 'normal'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dueAt == null
                      ? 'Set due date'
                      : 'Due ${MaterialLocalizations.of(context).formatShortDate(_dueAt!)}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create task'),
        ),
      ],
    );
  }
}

class _TaskOverview extends StatefulWidget {
  final List<Plan> plans;
  final List<AppUser> staff;
  final Map<String, String> clientNames;

  const _TaskOverview({
    required this.plans,
    required this.staff,
    required this.clientNames,
  });

  @override
  State<_TaskOverview> createState() => _TaskOverviewState();
}

class _TaskOverviewState extends State<_TaskOverview> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedPlanId;
  String? _selectedClientId;
  String? _selectedStaffId;
  String? _selectedCategory;
  bool? _showCompleted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<TaskItem>>{};
    for (final plan in widget.plans) {
      for (final rawFeature in plan.features) {
        final category = parseFeature(rawFeature).category;
        final units = _contentUnitCount(parseFeature(rawFeature).text);
        if (units == null) {
          categories
              .putIfAbsent(category, () => [])
              .add(TaskItem(rawFeature: rawFeature, plan: plan));
        } else {
          for (var unit = 1; unit <= units; unit++) {
            categories
                .putIfAbsent(category, () => [])
                .add(
                  TaskItem(
                    rawFeature: rawFeature,
                    plan: plan,
                    unitIndex: unit,
                    unitTotal: units,
                  ),
                );
          }
        }
      }
    }

    final allItems = categories.values.expand((items) => items).toList();
    final archivedItems = allItems.where((task) => task.isArchived).toList();
    final visibleItems = allItems.where((task) => !task.isArchived).toList();
    final completedCount = visibleItems
        .where((task) => task.isWorkflowCompleted)
        .length;
    final activeItems = visibleItems
        .where((task) => !task.isWorkflowCompleted)
        .toList();
    final planOptions = <String, Plan>{
      for (final task in allItems) task.plan.id: task.plan,
    };
    final clientOptions = <String, String>{
      for (final task in allItems) task.plan.clientId: _clientName(task.plan),
    };
    final staffOptions = <String, String>{
      for (final user in widget.staff)
        user.uid: user.name.isEmpty ? user.email : user.name,
    };
    final totalTasks = activeItems.length;
    if (categories.isEmpty) {
      return const Center(child: Text('No tasks found in assigned plans'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TaskSummaryCard(
          title: 'Assign Tasks',
          total: visibleItems.length,
          counts: {
            'Active': totalTasks,
            'Completed': completedCount,
            'Archived': archivedItems.length,
            for (final entry in categories.entries)
              entry.key: entry.value.where((task) => !task.isArchived).length,
          },
        ),
        const SizedBox(height: 16),
        ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 290,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search tasks',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            }),
                          ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              _TaskFilterDropdown(
                label: 'Plan',
                value: _selectedPlanId,
                items: [
                  for (final plan in planOptions.values)
                    DropdownMenuItem(value: plan.id, child: Text(plan.name)),
                ],
                onChanged: (value) => setState(() => _selectedPlanId = value),
              ),
              _TaskFilterDropdown(
                label: 'Client',
                value: _selectedClientId,
                items: [
                  for (final entry in clientOptions.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedClientId = value),
              ),
              _TaskFilterDropdown(
                label: 'Assigned staff',
                value: _selectedStaffId,
                items: [
                  for (final entry in staffOptions.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedStaffId = value),
              ),
              _TaskFilterDropdown(
                label: 'Task category',
                value: _selectedCategory,
                items: [
                  for (final category in categories.keys)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) => setState(() {
                  _selectedCategory = value;
                  _showCompleted = value == null ? false : null;
                }),
              ),
              if (_hasDeliveryFilters)
                TextButton.icon(
                  onPressed: _clearDeliveryFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final selectedEntries = categories.entries.where(
                (entry) =>
                    _selectedCategory == null || entry.key == _selectedCategory,
              );
              final selectedTasks = selectedEntries
                  .expand((entry) => entry.value)
                  .where((task) => !task.isArchived)
                  .where(
                    (task) =>
                        _showCompleted == null ||
                        task.isWorkflowCompleted == _showCompleted,
                  )
                  .where(_matchesDeliveryFilters)
                  .toList();
              final completed = selectedTasks
                  .where((task) => task.isWorkflowCompleted)
                  .length;
              return Column(
                children: [
                  LinearProgressIndicator(
                    value: selectedTasks.isEmpty
                        ? 0
                        : completed / selectedTasks.length,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${selectedTasks.length} tasks shown'),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in selectedEntries)
                    for (final task in entry.value.where(
                      (task) =>
                          !task.isArchived && _matchesDeliveryFilters(task),
                    ))
                      if (_showCompleted == null ||
                          task.isWorkflowCompleted == _showCompleted)
                        TaskRow(
                          task: task,
                          category: entry.key,
                          clientName: _clientName(task.plan),
                        ),
                ],
              );
            },
          ),
          _ArchivedTasksSection(
            tasks: archivedItems,
            clientNameFor: _clientName,
          ),
        ],
      ],
    );
  }

  int? _contentUnitCount(String text) {
    final match = RegExp(
      r'^(\d+)\s+(reels?|designs?|videos?)',
      caseSensitive: false,
    ).firstMatch(text.trim());
    final count = int.tryParse(match?.group(1) ?? '');
    return count != null && count > 0 ? count : null;
  }

  bool get _hasDeliveryFilters =>
      _searchQuery.isNotEmpty ||
      _selectedPlanId != null ||
      _selectedClientId != null ||
      _selectedStaffId != null ||
      _selectedCategory != null ||
      _showCompleted != false;

  void _clearDeliveryFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedPlanId = null;
      _selectedClientId = null;
      _selectedStaffId = null;
      _selectedCategory = null;
      _showCompleted = false;
    });
  }

  bool _matchesDeliveryFilters(TaskItem task) {
    if (_selectedPlanId != null && task.plan.id != _selectedPlanId) {
      return false;
    }
    if (_selectedClientId != null && task.plan.clientId != _selectedClientId) {
      return false;
    }
    if (_selectedStaffId != null &&
        taskAssigneeId(task.plan, task.workflowKey) != _selectedStaffId) {
      return false;
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final clientName = _clientName(task.plan);
    final searchable = [
      task.displayText,
      parseFeature(task.rawFeature).category,
      task.plan.name,
      clientName,
      taskAssigneeName(task.plan, task.workflowKey) ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  String _clientName(Plan plan) => plan.clientId == _internalPracticeClientId
      ? _internalPracticeLabel
      : widget.clientNames[plan.clientId] ?? 'Unknown client';
}

class _TaskFilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _TaskFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('All')),
        ...items,
      ],
      onChanged: onChanged,
    ),
  );
}

class _TaskSummaryCard extends StatelessWidget {
  final String title;
  final int total;
  final Map<String, int> counts;

  const _TaskSummaryCard({
    required this.title,
    required this.total,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title  $total', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final entry in counts.entries)
                Text(
                  '${entry.key}: ${entry.value}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class TaskRow extends ConsumerWidget {
  final TaskItem task;
  final String category;
  final String clientName;
  final String? lockedAssigneeId;

  const TaskRow({
    required this.task,
    required this.category,
    required this.clientName,
    this.lockedAssigneeId,
  });

  Future<void> _openWorkflow(
    BuildContext context,
    WidgetRef ref,
    List<AppUser> staff,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TaskWorkflowDialog(
        task: task,
        clientName: clientName,
        ref: ref,
        staff: staff,
        lockedAssigneeId: lockedAssigneeId,
      ),
    );
  }

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    bool isArchived,
  ) async {
    try {
      await ref
          .read(firestoreServiceProvider)
          .updatePlan(setTaskArchived(task.plan, task.workflowKey, isArchived));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArchived
                  ? '${task.displayText} archived'
                  : '${task.displayText} restored',
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

  Future<void> _setTimerRunning(
    BuildContext context,
    WidgetRef ref,
    bool isRunning,
  ) async {
    try {
      await ref
          .read(firestoreServiceProvider)
          .updatePlan(
            setTaskTimerRunning(task.plan, task.workflowKey, isRunning),
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update timer: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = task.displayText;
    final staff = ref.watch(allUsersProvider).valueOrNull ?? const <AppUser>[];
    final activeCycle = currentTaskCycle(task.plan, task.workflowKey);
    final cycleNumber = (activeCycle['cycle'] as num?)?.toInt();
    final assignee = taskAssigneeName(task.plan, task.workflowKey);
    final priority = taskPriority(task.plan, task.workflowKey);
    final startedAt = taskStartedAt(task.plan, task.workflowKey);
    final elapsed = taskElapsedTime(task.plan, task.workflowKey);
    final timerRunning = taskTimerIsRunning(task.plan, task.workflowKey);
    final dueAt = taskDueAt(task.plan, task.workflowKey);
    final dueState = _deliveryDueState(dueAt);
    final statusLabel = [
      if (assignee != null) assignee,
      if (cycleNumber != null) 'Draft $cycleNumber',
      timerRunning ? 'Working' : task.status.label,
      if (task.status == TaskStatus.draftCycle)
        draftCycleStage(task.plan, task.workflowKey).label,
    ].join(' • ');
    final priorityColors = priorityBadgeColors(priority);
    final showStatus = !task.isWorkflowCompleted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: priorityColors.$1,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(
            task.isWorkflowCompleted
                ? Icons.verified
                : Icons.assignment_outlined,
            color: task.isWorkflowCompleted ? Colors.green : priorityColors.$2,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      task.source.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (elapsed != null) ...[
                    _TaskTimerBadge(
                      initialElapsed: timerRunning
                          ? taskElapsedBeforeCurrentRun(
                              task.plan,
                              task.workflowKey,
                            )
                          : elapsed,
                      runningSince: timerRunning ? startedAt : null,
                    ),
                  ],
                  if (showStatus) ...[
                    if (dueState != null) ...[_DueStateBadge(state: dueState)],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        priorityLabel(priority),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: priorityColors.$2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          subtitle: Text(
            '$category • Client: $clientName'
            '${dueAt == null ? '' : ' • ${MaterialLocalizations.of(context).formatShortDate(dueAt)}'}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!task.isWorkflowCompleted && !task.isArchived)
                IconButton(
                  tooltip: timerRunning
                      ? 'Stop work'
                      : elapsed == null
                      ? 'Start work'
                      : 'Resume work',
                  icon: Icon(
                    timerRunning
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  onPressed: () =>
                      _setTimerRunning(context, ref, !timerRunning),
                ),
              IconButton(
                tooltip: task.isArchived ? 'Restore task' : 'Archive task',
                icon: Icon(
                  task.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                onPressed: () => _setArchived(context, ref, !task.isArchived),
              ),
              const Icon(Icons.edit_note_outlined),
            ],
          ),
          onTap: () => _openWorkflow(context, ref, staff),
        ),
      ),
    );
  }
}

enum _DueStateKind { today, upcoming, overdue }

class _DueState {
  final _DueStateKind kind;
  final int days;

  const _DueState(this.kind, this.days);

  String get label => switch (kind) {
    _DueStateKind.today => 'Due today',
    _DueStateKind.upcoming => 'Due in $days ${days == 1 ? 'day' : 'days'}',
    _DueStateKind.overdue => '$days ${days == 1 ? 'day' : 'days'} overdue',
  };
}

_DueState? _deliveryDueState(DateTime? dueAt, {DateTime? now}) {
  if (dueAt == null) return null;
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
  final difference = due.difference(today).inDays;
  if (difference == 0) return const _DueState(_DueStateKind.today, 0);
  if (difference > 0) return _DueState(_DueStateKind.upcoming, difference);
  return _DueState(_DueStateKind.overdue, difference.abs());
}

class _DueStateBadge extends StatelessWidget {
  final _DueState state;

  const _DueStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state.kind) {
      _DueStateKind.today => const Color(0xFF8A4B00),
      _DueStateKind.upcoming => const Color(0xFF174A8B),
      _DueStateKind.overdue => const Color(0xFF9C1C1C),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TaskTimerBadge extends StatefulWidget {
  final Duration initialElapsed;
  final DateTime? runningSince;

  const _TaskTimerBadge({
    required this.initialElapsed,
    required this.runningSince,
  });

  @override
  State<_TaskTimerBadge> createState() => _TaskTimerBadgeState();
}

class _TaskTimerBadgeState extends State<_TaskTimerBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTimer();
  }

  @override
  void didUpdateWidget(covariant _TaskTimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runningSince != widget.runningSince ||
        oldWidget.initialElapsed != widget.initialElapsed) {
      _scheduleTimer();
    }
  }

  void _scheduleTimer() {
    _timer?.cancel();
    if (widget.runningSince != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSegment = widget.runningSince == null
        ? Duration.zero
        : DateTime.now().difference(widget.runningSince!);
    final safeSegment = currentSegment.isNegative
        ? Duration.zero
        : currentSegment;
    final elapsed = widget.initialElapsed + safeSegment;
    final label = widget.runningSince == null ? 'Total' : 'Elapsed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16),
          const SizedBox(width: 5),
          Text(
            '$label ${_formatTaskDuration(elapsed)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTaskDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
}

class TaskItem {
  final String rawFeature;
  final Plan plan;
  final int? unitIndex;
  final int? unitTotal;

  const TaskItem({
    required this.rawFeature,
    required this.plan,
    this.unitIndex,
    this.unitTotal,
  });

  int get progress {
    if (plan.completedFeatures.contains(rawFeature)) return 100;
    return plan.featureProgress[rawFeature] ?? 0;
  }

  bool get isCompleted => progress >= 100;

  int get completedUnits {
    if (unitTotal == null) return isCompleted ? 1 : 0;
    return ((progress / 100) * unitTotal!).round().clamp(0, unitTotal!);
  }

  bool get unitIsCompleted =>
      unitTotal != null ? completedUnits >= unitIndex! : isCompleted;

  String get workflowKey => taskKey(rawFeature, unitIndex);

  TaskStatus get status => taskStatus(plan, workflowKey);

  bool get isArchived => taskIsArchived(plan, workflowKey);

  ClientTaskSource get source =>
      plan.taskForFeature(rawFeature)?.source ?? ClientTaskSource.template;

  bool get isWorkflowCompleted => status == TaskStatus.completed;

  String get displayText {
    if (unitIndex == null || unitTotal == null) {
      return parseFeature(rawFeature).text;
    }
    final text = parseFeature(rawFeature).text;
    final match = RegExp(
      r'^(\d+)\s+(reels?|designs?|videos?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return text;
    final type = match.group(2)!;
    final singular = type.endsWith('s')
        ? type.substring(0, type.length - 1)
        : type;
    return '${singular[0].toUpperCase()}${singular.substring(1)} $unitIndex/$unitTotal';
  }
}

class _ArchivedTasksSection extends StatelessWidget {
  final List<TaskItem> tasks;
  final String Function(Plan plan) clientNameFor;

  const _ArchivedTasksSection({
    required this.tasks,
    required this.clientNameFor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 24),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.archive_outlined),
        title: Text('Archived (${tasks.length})'),
        children: [
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No archived tasks'),
            )
          else
            for (final task in tasks)
              TaskRow(
                task: task,
                category: parseFeature(task.rawFeature).category,
                clientName: clientNameFor(task.plan),
              ),
        ],
      ),
    ),
  );
}

extension _TaskStatusLabels on TaskStatus {
  String get label => switch (this) {
    TaskStatus.notAssigned => 'Not assigned',
    TaskStatus.assigned => 'Assigned',
    TaskStatus.started => 'Start',
    TaskStatus.draftCycle => 'Draft cycle',
    TaskStatus.completed => 'Complete',
  };
}

extension _DraftCycleStageLabels on DraftCycleStage {
  String get label => switch (this) {
    DraftCycleStage.instructions => 'Instructions',
    DraftCycleStage.working => 'Working',
    DraftCycleStage.confirmation => 'Confirmation',
  };
}

String priorityLabel(String priority) => switch (priority) {
  'low' => 'Low priority',
  'high' => 'High priority',
  'urgent' => 'Urgent',
  _ => 'Normal priority',
};

(Color, Color) priorityBadgeColors(String priority) => switch (priority) {
  'low' => (const Color(0xFFE5E7EB), const Color(0xFF374151)),
  'high' => (const Color(0xFFFFE4B5), const Color(0xFF8A4B00)),
  'urgent' => (const Color(0xFFFFDAD6), const Color(0xFF9C1C1C)),
  _ => (const Color(0xFFDCEBFF), const Color(0xFF174A8B)),
};

class TaskWorkflowDialog extends StatefulWidget {
  final TaskItem task;
  final String clientName;
  final WidgetRef ref;
  final List<AppUser> staff;
  final String? lockedAssigneeId;
  final String? lockedAssigneeName;

  const TaskWorkflowDialog({
    required this.task,
    required this.clientName,
    required this.ref,
    required this.staff,
    this.lockedAssigneeId,
    this.lockedAssigneeName,
  });

  @override
  State<TaskWorkflowDialog> createState() => _TaskWorkflowDialogState();
}

class _TaskWorkflowDialogState extends State<TaskWorkflowDialog> {
  late TaskStatus _status;
  late DraftCycleStage _draftStage;
  late List<Map<String, dynamic>> _drafts;
  late String _priority;
  late String _category;
  String? _subcategory;
  late final TextEditingController _titleController;
  late final TextEditingController _internalNotesController;
  DateTime? _dueAt;
  String? _assignedTo;
  String? _error;
  bool _saving = false;

  bool get _awaitingAdminReview =>
      _status == TaskStatus.draftCycle &&
      _draftStage == DraftCycleStage.confirmation &&
      (_drafts.isEmpty
          ? false
          : _drafts.last['reviewRequestedFrom']?.toString() == 'admin');

  Future<void> _resolveAdminReview(String decision) async {
    Plan updated = widget.task.plan;
    if (decision == 'changes') {
      updated = createNextDraftCycle(updated, widget.task.workflowKey);
    } else if (decision == 'client') {
      updated = submitTaskForReview(
        updated,
        widget.task.workflowKey,
        reviewer: 'client',
      );
    } else {
      updated = completeReviewedTask(updated, widget.task.workflowKey);
    }
    try {
      await widget.ref.read(firestoreServiceProvider).updatePlan(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resolve review: $error')),
        );
      }
    }
  }

  void _syncDraftStatuses() {
    for (var index = 0; index < _drafts.length; index++) {
      _drafts[index] = {..._drafts[index], 'status': _status.name};
    }
  }

  void _syncCurrentDraftStage() {
    if (_drafts.isEmpty) return;
    final latestCycle = _drafts
        .map((draft) => (draft['cycle'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final index = _drafts.indexWhere(
      (draft) => (draft['cycle'] as num?)?.toInt() == latestCycle,
    );
    if (index < 0) return;
    _drafts[index] = {
      ..._drafts[index],
      'draftStage': _draftStage.name,
      'clientConfirmed': false,
    };
  }

  bool get _currentDraftConfirmed {
    if (_drafts.isEmpty) return false;
    final latestCycle = _drafts
        .map((draft) => (draft['cycle'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final draft = _drafts.firstWhere(
      (item) => (item['cycle'] as num?)?.toInt() == latestCycle,
    );
    return draft['clientConfirmed'] == true;
  }

  void _confirmCurrentDraft() {
    if (_drafts.isEmpty) return;
    final latestCycle = _drafts
        .map((draft) => (draft['cycle'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final index = _drafts.indexWhere(
      (draft) => (draft['cycle'] as num?)?.toInt() == latestCycle,
    );
    if (index < 0) return;
    _drafts[index] = {
      ..._drafts[index],
      'draftStage': DraftCycleStage.confirmation.name,
      'clientConfirmed': true,
    };
  }

  void _updateDraftInstructions(int cycleNumber, String instructions) {
    final index = _drafts.indexWhere(
      (draft) => (draft['cycle'] as num?)?.toInt() == cycleNumber,
    );
    if (index < 0) return;
    _drafts[index] = {
      ..._drafts[index],
      'instructions': instructions,
      'clientConfirmed': false,
    };
  }

  void _updateDraftLink(int cycleNumber, String draftLink) {
    final index = _drafts.indexWhere(
      (draft) => (draft['cycle'] as num?)?.toInt() == cycleNumber,
    );
    if (index < 0) return;
    _drafts[index] = {
      ..._drafts[index],
      'draftLink': draftLink,
      'clientConfirmed': false,
    };
  }

  Future<void> _openDraftLink(String rawLink) async {
    final uri = Uri.tryParse(rawLink.trim());
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid http or https link first')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open draft link')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final parsedFeature = parseFeature(widget.task.rawFeature);
    final categorySelection = parseFeatureCategory(parsedFeature.category);
    _category = customTaskFeatureCategories.contains(categorySelection.category)
      ? categorySelection.category
      : customTaskFeatureCategories.first;
    final subcategories = planFeatureSubcategories[_category] ?? const <String>[];
    _subcategory = subcategories.contains(categorySelection.subcategory)
      ? categorySelection.subcategory
      : subcategories.firstOrNull;
    _titleController = TextEditingController(text: parsedFeature.text);
    _drafts = taskCycles(widget.task.plan, widget.task.workflowKey)
        .where((draft) => (draft['cycle'] as num?) != null)
        .map((draft) => Map<String, dynamic>.from(draft))
        .toList();
    _status = widget.task.status;
    _draftStage = draftCycleStage(widget.task.plan, widget.task.workflowKey);
    _priority = taskPriority(widget.task.plan, widget.task.workflowKey);
    _internalNotesController = TextEditingController(
      text: taskInternalNotes(widget.task.plan, widget.task.workflowKey),
    );
    _dueAt = taskDueAt(widget.task.plan, widget.task.workflowKey);
    final savedAssignee = taskAssigneeId(
      widget.task.plan,
      widget.task.workflowKey,
    );
    _assignedTo =
        widget.lockedAssigneeId ??
        (widget.staff.any((user) => user.uid == savedAssignee)
            ? savedAssignee
            : null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Task title is required.');
      return;
    }
    final encodedCategory = encodeFeatureCategory(_category, _subcategory);
    final newFeature = encodePlanTaskFeature(encodedCategory, title);
    if (newFeature != widget.task.rawFeature &&
        widget.task.plan.features.contains(newFeature)) {
      setState(() => _error = 'A task with this category and title exists.');
      return;
    }
    _syncDraftStatuses();
    if (_status == TaskStatus.draftCycle) {
      _syncCurrentDraftStage();
    }
    if (_status == TaskStatus.completed &&
        _drafts.isNotEmpty &&
        !_currentDraftConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client confirmation is required first')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final renamedPlan = renamePlanTask(
      widget.task.plan,
      widget.task.rawFeature,
      category: encodedCategory,
      title: title,
    );
    final workflowKey = taskKey(newFeature, widget.task.unitIndex);
    final cyclesUpdated = _drafts.isEmpty
        ? setTaskStatus(renamedPlan, workflowKey, _status)
        : replaceTaskWorkflowCycles(
            renamedPlan,
            workflowKey,
            _drafts,
          );
    final assignedUser = widget.staff
        .where((user) => user.uid == _assignedTo)
        .firstOrNull;
    final assigned = updateTaskAssignment(
      cyclesUpdated,
      workflowKey,
      assignedTo: _status == TaskStatus.notAssigned
          ? null
          : (widget.lockedAssigneeId ?? assignedUser?.uid),
      assignedToName: assignedUser == null
          ? (_status == TaskStatus.notAssigned
            ? null
            : widget.lockedAssigneeName)
          : (assignedUser.name.isEmpty
                ? assignedUser.email
                : assignedUser.name),
      priority: _priority,
    );
    final updated = updateTaskManagementDetails(
      assigned,
      workflowKey,
      dueAt: _dueAt,
      internalNotes: _internalNotesController.text,
    );
    try {
      await widget.ref.read(firestoreServiceProvider).updatePlan(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save task: $error')));
      }
    }
  }

  Future<void> _complete() async {
    setState(() {
      _status = TaskStatus.completed;
      _confirmCurrentDraft();
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final orderedDrafts = [..._drafts]
      ..sort((a, b) {
        final aNumber = (a['cycle'] as num?)?.toInt() ?? 0;
        final bNumber = (b['cycle'] as num?)?.toInt() ?? 0;
        return bNumber.compareTo(aNumber);
      });
    return AlertDialog(
      title: const Text('Task Details'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in customTaskFeatureCategories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                      final options =
                          planFeatureSubcategories[value] ?? const <String>[];
                      _subcategory = options.firstOrNull;
                    });
                  }
                },
              ),
              if ((planFeatureSubcategories[_category] ?? const []).isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('edit-subcategory-$_category'),
                  initialValue: _subcategory,
                  decoration: const InputDecoration(labelText: 'Subcategory'),
                  items: [
                    for (final subcategory
                        in planFeatureSubcategories[_category]!)
                      DropdownMenuItem(
                        value: subcategory,
                        child: Text(subcategory),
                      ),
                  ],
                  onChanged: (subcategory) =>
                      setState(() => _subcategory = subcategory),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                widget.clientName,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _assignedTo,
                      decoration: const InputDecoration(
                        labelText: 'Assigned staff',
                      ),
                      items: [
                        if (widget.lockedAssigneeId != null)
                          DropdownMenuItem<String?>(
                            value: widget.lockedAssigneeId,
                            child: Text(widget.lockedAssigneeName ?? 'Myself'),
                          )
                        else ...[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Not assigned'),
                          ),
                          for (final user in widget.staff)
                            DropdownMenuItem<String?>(
                              value: user.uid,
                              child: Text(
                                user.name.isEmpty ? user.email : user.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ],
                      onChanged: widget.lockedAssigneeId == null
                          ? (value) {
                              setState(() {
                                _assignedTo = value;
                                if (value == null) {
                                  _status = TaskStatus.notAssigned;
                                } else if (_status == TaskStatus.notAssigned) {
                                  _status = TaskStatus.assigned;
                                }
                                _syncDraftStatuses();
                              });
                            }
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<TaskStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final status in TaskStatus.values)
                          if (widget.lockedAssigneeId == null ||
                              status != TaskStatus.notAssigned)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                      ],
                      onChanged: (status) {
                        if (status == null) return;
                        setState(() {
                          _status = status;
                          if (status == TaskStatus.notAssigned) {
                            _assignedTo = null;
                          }
                          _syncDraftStatuses();
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_awaitingAdminReview) ...[
                const SizedBox(height: 10),
                Text(
                  'Awaiting admin review',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _resolveAdminReview('changes'),
                      icon: const Icon(Icons.reply_outlined),
                      label: const Text('Request changes'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _resolveAdminReview('client'),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Send to client approval'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _resolveAdminReview('complete'),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Approve and complete'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dueAt == null
                      ? 'Set due date'
                      : 'Due ${MaterialLocalizations.of(context).formatShortDate(_dueAt!)}',
                ),
              ),
              if (_dueAt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _dueAt = null),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear due date'),
                  ),
                ),
              TextField(
                controller: _internalNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Internal project notes',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Drafts', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _assignedTo == null
                        ? null
                        : () {
                            setState(() {
                              final nextCycle = orderedDrafts.isEmpty
                                  ? 1
                                  : ((orderedDrafts.first['cycle'] as num?)
                                                ?.toInt() ??
                                            0) +
                                        1;
                              _drafts.insert(0, {
                                'cycle': nextCycle,
                                'status': TaskStatus.draftCycle.name,
                                'draftStage': DraftCycleStage.instructions.name,
                                'instructions': '',
                                'update': '',
                                'clientConfirmed': false,
                              });
                              _status = TaskStatus.draftCycle;
                              _draftStage = DraftCycleStage.instructions;
                              _syncDraftStatuses();
                            });
                          },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New draft'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderedDrafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final draft = orderedDrafts[index];
                  final draftNumber = (draft['cycle'] as num?)?.toInt() ?? 1;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Draft $draftNumber',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete draft',
                              onPressed: () {
                                setState(() {
                                  _drafts.removeWhere(
                                    (item) =>
                                        (item['cycle'] as num?)?.toInt() ==
                                        draftNumber,
                                  );
                                  if (_drafts.isEmpty) {
                                    _status = _assignedTo == null
                                        ? TaskStatus.notAssigned
                                        : TaskStatus.assigned;
                                  }
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey('draft-instructions-$draftNumber'),
                          initialValue: draft['instructions']?.toString() ?? '',
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (value) {
                            _updateDraftInstructions(draftNumber, value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Client instructions',
                            hintText:
                                'What should the client provide or approve?',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: ValueKey('draft-link-$draftNumber'),
                          initialValue: draft['draftLink']?.toString() ?? '',
                          keyboardType: TextInputType.url,
                          onChanged: (value) =>
                              _updateDraftLink(draftNumber, value),
                          decoration: const InputDecoration(
                            labelText: 'Draft link',
                            hintText:
                                'Link to the completed draft or deliverable',
                            prefixIcon: Icon(Icons.link_outlined),
                          ),
                        ),
                        if ((draft['draftLink']?.toString().trim() ?? '')
                            .isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _openDraftLink(
                                draft['draftLink']?.toString() ?? '',
                              ),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open link'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_status != TaskStatus.completed)
          OutlinedButton.icon(
            onPressed: _saving || _assignedTo == null ? null : _complete,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete'),
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
          label: const Text('Save changes'),
        ),
      ],
    );
  }
}

