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
import 'package:tulasisolutionssite/core/tasks/task_save_controller.dart';
import 'sales_record_dialog.dart';
import 'task_deletion_dialog.dart';
import 'unlinked_plan_repair.dart';
import '../../../core/widgets/task_tracking_widgets.dart';
import '../../../core/widgets/retained_task_edits.dart';

const _internalPracticeClientId = '__internal_practice__';
const _internalPracticePlanId = 'internal-practice-tasks';
const _internalPracticeLabel = 'Practice (Internal)';
const _unlinkedClientFilter = '__unlinked_tasks__';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(visiblePlansProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    final taskClientsAsync = ref.watch(taskClientsProvider);
    final staff = ref.watch(allUsersProvider).valueOrNull ?? const <AppUser>[];
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/tasks',
      title: 'Assign Tasks',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(allPlansStreamProvider);
            ref.invalidate(clientsListProvider);
            ref.invalidate(taskClientsProvider);
          },
        ),
      ],
      floatingActionButton: plansAsync.maybeWhen(
        data: (plans) => clientsAsync.maybeWhen(
          data: (clients) => FloatingActionButton.extended(
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (_) => CustomTaskDialog(
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
        data: (plans) => taskClientsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingWidget(),
          error: (error, stackTrace) => CustomErrorWidget(
            message: 'Error loading task clients: $error',
            onRetry: () {
              ref.invalidate(clientsListProvider);
              ref.invalidate(taskClientsProvider);
            },
          ),
          data: (clients) => _TaskOverview(
            plans: plans,
            staff: staff,
            completedOnly: false,
            clientNames: {for (final client in clients) client.id: client.name},
          ),
        ),
      ),
    );
  }
}

class CompletedTasksScreen extends ConsumerWidget {
  const CompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(visiblePlansProvider);
    final clientsAsync = ref.watch(taskClientsProvider);
    final staff = ref.watch(allUsersProvider).valueOrNull ?? const <AppUser>[];
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/completed-tasks',
      title: 'Completed Tasks',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(allPlansStreamProvider);
            ref.invalidate(clientsListProvider);
            ref.invalidate(taskClientsProvider);
          },
        ),
      ],
      body: plansAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading tasks: $error'),
        data: (plans) => clientsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingWidget(),
          error: (error, stackTrace) => CustomErrorWidget(
            message: 'Error loading task clients: $error',
            onRetry: () {
              ref.invalidate(clientsListProvider);
              ref.invalidate(taskClientsProvider);
            },
          ),
          data: (clients) => _TaskOverview(
            plans: plans,
            staff: staff,
            completedOnly: true,
            clientNames: {for (final client in clients) client.id: client.name},
          ),
        ),
      ),
    );
  }
}

class CustomTaskDialog extends ConsumerStatefulWidget {
  final List<Plan> plans;
  final List<Client> clients;
  final List<AppUser> staff;
  final bool selfAssignOnly;
  final String? initialClientId;
  final bool salesOnly;

  const CustomTaskDialog({
    super.key,
    required this.plans,
    required this.clients,
    required this.staff,
    this.selfAssignOnly = false,
    this.initialClientId,
    this.salesOnly = false,
  });

  @override
  ConsumerState<CustomTaskDialog> createState() => _CustomTaskDialogState();
}

class _CustomTaskDialogState extends ConsumerState<CustomTaskDialog> {
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
  void initState() {
    super.initState();
    _clientId = widget.initialClientId;
    if (widget.salesOnly) {
      _category = salesFeatureCategory;
      _subcategory = 'Call';
    }
  }

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
        widget.plans
            .where(
              (plan) =>
                  plan.clientId == _clientId &&
                  (_category == salesFeatureCategory
                      ? plan.name == 'Sales Tasks'
                      : plan.name != 'Sales Tasks'),
            )
            .toList()
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
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_dueAt!),
    );
    if (time != null && mounted) {
      setState(
        () => _dueAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    final currentProfile = ref.read(currentUserProfileProvider).valueOrNull;
    if (_category == salesFeatureCategory &&
        currentProfile?.canAccessPanel('tasks') != true) {
      setState(
        () => _error = 'Sales task creation requires Assign Tasks access.',
      );
      return;
    }
    if (widget.selfAssignOnly &&
        (currentProfile == null ||
            !ref.read(currentStaffIdsProvider).contains(currentProfile.uid))) {
      setState(() => _error = 'Sign in to create a task for yourself.');
      return;
    }
    final personalCreation =
        widget.selfAssignOnly &&
        currentProfile?.canAccessPanel('tasks') != true &&
        currentProfile?.canAccessPanel('plans') != true;
    final plan = personalCreation ? null : _selectedPlan;
    final title = _titleController.text.trim();
    final reason = _reasonController.text.trim();
    final subcategories = _category == null
        ? const <String>[]
        : planFeatureSubcategories[_category] ?? const <String>[];
    if (_clientId == null ||
        title.isEmpty ||
        _category == null ||
        (subcategories.isNotEmpty && _subcategory == null) ||
        (reason.isEmpty && _category != salesFeatureCategory)) {
      setState(
        () => _error =
            'Client, title, category, subcategory, and reason are required.',
      );
      return;
    }
    if (_category == salesFeatureCategory &&
        (_isInternalPractice ||
            _dueAt == null ||
            (!widget.selfAssignOnly && _assignedTo == null))) {
      setState(
        () => _error =
            'Sales tasks need a customer, assigned staff, and due date/time.',
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
            id: _isInternalPractice && !personalCreation
                ? _internalPracticePlanId
                : const Uuid().v4(),
            clientId: _clientId!,
            type: PlanType.setup,
            name: _isInternalPractice
                ? _internalPracticeLabel
                : _category == salesFeatureCategory
                ? 'Sales Tasks'
                : 'Custom Tasks',
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
        addedReason: reason.isEmpty ? title : reason,
      );
      if (_category == salesFeatureCategory &&
          targetPlan.features.contains(task.feature)) {
        setState(
          () => _error =
              'A sales task with this action and title already exists. Use a different title.',
        );
        return;
      }
      final createdAt = DateTime.now();
      final updatedPlan = recordTaskCreation(
        targetPlan.copyWith(
          features: [...targetPlan.features, task.feature],
          tasks: [...targetPlan.tasks, task],
        ),
        task.feature,
        actor: currentProfile,
        now: createdAt,
      );
      final assignedUser = widget.selfAssignOnly
          ? currentProfile
          : widget.staff.where((user) => user.uid == _assignedTo).firstOrNull;
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
        actor: currentProfile,
        now: createdAt,
      );
      final detailedPlan = updateTaskManagementDetails(
        assignedPlan,
        task.feature,
        dueAt: _dueAt,
        internalNotes: reason,
        actor: currentProfile,
      );
      final service = ref.read(firestoreServiceProvider);
      ref
          .read(taskSavesProvider.notifier)
          .submit(
            desired: detailedPlan,
            previous: plan,
            label: title,
            workflowKey: task.feature,
            lockedAssigneeId: widget.selfAssignOnly ? assignedUser?.uid : null,
            persist: () => plan == null
                ? service.createPlan(detailedPlan, ifAbsent: true)
                : service.updatePlan(detailedPlan, previous: plan),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not add task: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = ref.watch(currentUserProfileProvider).valueOrNull;
    final selfAssignmentReady =
        !widget.selfAssignOnly ||
        ref.watch(currentStaffIdsProvider).contains(currentProfile?.uid);
    const taskStages = {ClientStage.client, ClientStage.retain, ClientStage.refer};
    final taskClients =
        widget.clients
            .where(
              (client) =>
                  !client.isArchived && taskStages.contains(client.stage),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    return AlertDialog(
      title: Text(widget.salesOnly ? 'Create Sales Task' : 'Task Details'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.initialClientId != null)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Customer'),
                  child: Text(
                    widget.clients
                        .firstWhere(
                          (client) => client.id == widget.initialClientId,
                        )
                        .name,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: const ValueKey('create-task-client'),
                  initialValue: _clientId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Client'),
                  hint: taskClients.isEmpty
                      ? const Text(
                          'No Sale or Retain / Refer clients found',
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  items:
                      taskClients
                          .map(
                            (client) => DropdownMenuItem(
                              value: client.id,
                              child: Text(
                                client.name,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                  }),
                ),
              const SizedBox(height: 12),
              if (widget.salesOnly) ...[
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Current stage'),
                  child: Text(
                    widget.clients
                        .firstWhere((client) => client.id == _clientId)
                        .stage
                        .displayName,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 12),
              if (!widget.salesOnly)
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
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
                        : planFeatureSubcategories[category] ??
                              const <String>[];
                    _subcategory = options.firstOrNull;
                  }),
                ),
              if (_category != null &&
                  (planFeatureSubcategories[_category] ?? const [])
                      .isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('create-subcategory-$_category'),
                  initialValue: _subcategory,
                  decoration: InputDecoration(
                    labelText: _category == salesFeatureCategory
                        ? 'Action'
                        : 'Subcategory',
                  ),
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
              if (widget.selfAssignOnly)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Assigned staff',
                  ),
                  child: Text(
                    currentProfile == null
                        ? 'Unavailable'
                        : (currentProfile.name.isEmpty
                              ? currentProfile.email
                              : currentProfile.name),
                  ),
                )
              else
                DropdownButtonFormField<String?>(
                  key: const ValueKey('create-task-assignee'),
                  initialValue: _assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'Assigned staff',
                  ),
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
                      : 'Due ${MaterialLocalizations.of(context).formatShortDate(_dueAt!)} '
                            '${TimeOfDay.fromDateTime(_dueAt!).format(context)}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _category == salesFeatureCategory
                      ? 'Notes (optional)'
                      : 'Instructions',
                ),
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
          onPressed: _isSaving || !selfAssignmentReady ? null : _save,
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
  final bool completedOnly;

  const _TaskOverview({
    required this.plans,
    required this.staff,
    required this.clientNames,
    required this.completedOnly,
  });

  @override
  State<_TaskOverview> createState() => _TaskOverviewState();
}

enum _CompletedPeriod { all, day, week, month, custom }

class _TaskOverviewState extends State<_TaskOverview> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedClientId;
  String? _selectedStaffId;
  String? _selectedCategory;
  TaskDueFilter? _dueFilter;
  bool _unassignedOnly = false;
  Timer? _filterTimer;
  _CompletedPeriod? _completedPeriod;
  DateTimeRange? _customCompletedRange;
  DateTime _completedPeriodAnchor = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.completedOnly) _completedPeriod = _CompletedPeriod.all;
    _filterTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && !widget.completedOnly) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _TaskOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedClientId != null &&
        !widget.plans.any(
          (plan) =>
              plan.features.isNotEmpty &&
              _clientFilterKey(plan) == _selectedClientId,
        )) {
      _selectedClientId = null;
    }
    if (_selectedStaffId != null &&
        !widget.staff.any((user) => user.uid == _selectedStaffId)) {
      _selectedStaffId = null;
    }
  }

  @override
  void dispose() {
    _filterTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<TaskItem>>{};
    for (final plan in widget.plans) {
      for (final rawFeature in plan.features) {
        final category = isSalesTaskFeature(rawFeature)
            ? salesFeatureCategory
            : parseFeature(rawFeature).category;
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
    final completedItems = visibleItems
        .where((task) => task.isWorkflowCompleted)
        .toList();
    final displayedItems = widget.completedOnly ? completedItems : activeItems;
    final now = DateTime.now();
    final filterItems = activeItems
        .where(
          (task) =>
              _matchesDeliveryFilters(task) &&
              (_selectedCategory == null ||
                  (isSalesTaskFeature(task.rawFeature)
                          ? salesFeatureCategory
                          : parseFeature(task.rawFeature).category) ==
                      _selectedCategory),
        )
        .toList();
    String dueLabel(TaskDueFilter filter) => switch (filter) {
      TaskDueFilter.todayAndOverdue => 'Today & Overdue',
      TaskDueFilter.upcoming => 'Upcoming',
      TaskDueFilter.unscheduled => 'Unscheduled',
    };
    final availableCategories = categories.entries
        .where(
          (entry) => entry.value.any(
            (task) =>
                !task.isArchived &&
                task.isWorkflowCompleted == widget.completedOnly,
          ),
        )
        .map((entry) => entry.key)
        .toList();
    final clientOptions = <String, String>{
      for (final task in allItems)
        _clientFilterKey(
          task.plan,
        ): _clientFilterKey(task.plan) == _unlinkedClientFilter
            ? 'Unlinked tasks'
            : _clientName(task.plan),
    };
    final staffOptions = <String, String>{
      for (final user in widget.staff)
        user.uid: user.name.isEmpty ? user.email : user.name,
    };
    if (categories.isEmpty) {
      return const Center(child: Text('No tasks found in assigned plans'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TaskSummaryCard(
          title: widget.completedOnly ? 'Completed Tasks' : 'Assign Tasks',
          total: displayedItems.length,
          trailing: widget.completedOnly
              ? _buildCompletedPeriodControls(context)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final filter in TaskDueFilter.values)
                      FilterChip(
                        label: Text(
                          '${dueLabel(filter)} (${filterItems.where((task) => (!_unassignedOnly || taskAssigneeId(task.plan, task.workflowKey) == null) && matchesTaskDueFilter(task.plan, task.workflowKey, filter, now)).length})',
                        ),
                        selected: _dueFilter == filter,
                        onSelected: (selected) => setState(
                          () => _dueFilter = selected ? filter : null,
                        ),
                      ),
                    FilterChip(
                      label: Text(
                        'Unassigned (${filterItems.where((task) => taskAssigneeId(task.plan, task.workflowKey) == null && (_dueFilter == null || matchesTaskDueFilter(task.plan, task.workflowKey, _dueFilter!, now))).length})',
                      ),
                      selected: _unassignedOnly,
                      onSelected: (selected) =>
                          setState(() => _unassignedOnly = selected),
                    ),
                  ],
                ),
          counts: {
            if (widget.completedOnly)
              'Completed': completedCount
            else ...{
              'Active': activeItems.length,
              'Archived': archivedItems.length,
            },
            for (final category in availableCategories)
              category: categories[category]!
                  .where(
                    (task) =>
                        !task.isArchived &&
                        task.isWorkflowCompleted == widget.completedOnly,
                  )
                  .length,
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
                  for (final category in {
                    ...availableCategories,
                    if (_selectedCategory != null) _selectedCategory!,
                  })
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) => setState(() => _selectedCategory = value),
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
                  .where(_matchesTaskStatusFilters)
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
                          !task.isArchived &&
                          _matchesTaskStatusFilters(task) &&
                          _matchesDeliveryFilters(task),
                    ))
                      TaskRow(
                        task: task,
                        category: entry.key,
                        clientName: _clientName(task.plan),
                      ),
                ],
              );
            },
          ),
          if (!widget.completedOnly)
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

  Widget _buildCompletedPeriodControls(BuildContext context) =>
      CompletedPeriodControls<_CompletedPeriod>(
        segments: const [
          ButtonSegment(
            value: _CompletedPeriod.all,
            label: Text(
              'All days',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ButtonSegment(value: _CompletedPeriod.day, label: Text('Day')),
          ButtonSegment(value: _CompletedPeriod.week, label: Text('Week')),
          ButtonSegment(value: _CompletedPeriod.month, label: Text('Month')),
          ButtonSegment(value: _CompletedPeriod.custom, label: Text('Custom')),
        ],
        selected: _completedPeriod ?? _CompletedPeriod.all,
        onSelected: _selectCompletedPeriod,
        dateLabel: _completedPeriodLabel(context),
        onPrevious: _completedPeriod == _CompletedPeriod.all
            ? null
            : () => _moveCompletedPeriod(-1),
        onNext: _canMoveToNextCompletedPeriod
            ? () => _moveCompletedPeriod(1)
            : null,
        onSelectDates: () => _selectCompletedPeriod(_CompletedPeriod.custom),
      );

  bool get _hasDeliveryFilters =>
      _searchQuery.isNotEmpty ||
      _selectedClientId != null ||
      _selectedStaffId != null ||
      _selectedCategory != null ||
      _dueFilter != null ||
      _unassignedOnly ||
      (widget.completedOnly && _completedPeriod != _CompletedPeriod.all);

  void _clearDeliveryFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedClientId = null;
      _selectedStaffId = null;
      _selectedCategory = null;
      _dueFilter = null;
      _unassignedOnly = false;
      _completedPeriod = widget.completedOnly ? _CompletedPeriod.all : null;
      _customCompletedRange = null;
      _completedPeriodAnchor = DateUtils.dateOnly(DateTime.now());
    });
  }

  Future<void> _selectCompletedPeriod(_CompletedPeriod? period) async {
    if (period != _CompletedPeriod.custom) {
      setState(() {
        _completedPeriod = period;
        _customCompletedRange = null;
        _completedPeriodAnchor = DateUtils.dateOnly(DateTime.now());
      });
      return;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final selectedRange = await showDateRangePicker(
      context: context,
      initialDateRange:
          _customCompletedRange ?? DateTimeRange(start: today, end: today),
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Select completed date range',
      builder: (context, child) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            key: const ValueKey('completed-date-popup'),
            width: 480,
            height: 600,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: child!,
            ),
          ),
        ),
      ),
    );
    if (selectedRange == null || !mounted) return;
    setState(() {
      _completedPeriod = _CompletedPeriod.custom;
      _customCompletedRange = selectedRange;
    });
  }

  DateTimeRange? get _completedDateRange {
    final period = _completedPeriod;
    if (period == null) return null;
    return switch (period) {
      _CompletedPeriod.all => null,
      _CompletedPeriod.day => DateTimeRange(
        start: _completedPeriodAnchor,
        end: _completedPeriodAnchor,
      ),
      _CompletedPeriod.week => () {
        final start = _completedPeriodAnchor.subtract(
          Duration(days: _completedPeriodAnchor.weekday - DateTime.monday),
        );
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 6)),
        );
      }(),
      _CompletedPeriod.month => DateTimeRange(
        start: DateTime(
          _completedPeriodAnchor.year,
          _completedPeriodAnchor.month,
        ),
        end: DateTime(
          _completedPeriodAnchor.year,
          _completedPeriodAnchor.month + 1,
          0,
        ),
      ),
      _CompletedPeriod.custom => _customCompletedRange,
    };
  }

  bool get _canMoveToNextCompletedPeriod {
    final range = _completedDateRange;
    if (range == null) return false;
    return DateUtils.dateOnly(
      range.end,
    ).isBefore(DateUtils.dateOnly(DateTime.now()));
  }

  void _moveCompletedPeriod(int direction) {
    final period = _completedPeriod;
    if (period == null) return;
    setState(() {
      switch (period) {
        case _CompletedPeriod.all:
          return;
        case _CompletedPeriod.day:
          _completedPeriodAnchor = _completedPeriodAnchor.add(
            Duration(days: direction),
          );
        case _CompletedPeriod.week:
          _completedPeriodAnchor = _completedPeriodAnchor.add(
            Duration(days: 7 * direction),
          );
        case _CompletedPeriod.month:
          _completedPeriodAnchor = DateTime(
            _completedPeriodAnchor.year,
            _completedPeriodAnchor.month + direction,
          );
        case _CompletedPeriod.custom:
          final range = _customCompletedRange;
          if (range == null) return;
          final days = range.end.difference(range.start).inDays + 1;
          var start = range.start.add(Duration(days: days * direction));
          var end = range.end.add(Duration(days: days * direction));
          final today = DateUtils.dateOnly(DateTime.now());
          if (direction > 0 && end.isAfter(today)) {
            start = start.subtract(end.difference(today));
            end = today;
          }
          _customCompletedRange = DateTimeRange(start: start, end: end);
      }
    });
  }

  String _completedPeriodLabel(BuildContext context) {
    final range = _completedDateRange;
    if (range == null) return 'All days';
    final localizations = MaterialLocalizations.of(context);
    if (_completedPeriod == _CompletedPeriod.week) {
      final start = localizations.formatShortMonthDay(range.start);
      final end = localizations.formatShortMonthDay(range.end);
      return '$start - $end';
    }
    if (_completedPeriod == _CompletedPeriod.month) {
      return localizations.formatMonthYear(range.start);
    }
    final start = localizations.formatShortDate(range.start);
    final end = localizations.formatShortDate(range.end);
    return start == end ? start : '$start - $end';
  }

  bool _matchesTaskStatusFilters(TaskItem task) {
    if (task.isWorkflowCompleted != widget.completedOnly) return false;
    if (!widget.completedOnly) {
      if (_unassignedOnly &&
          taskAssigneeId(task.plan, task.workflowKey) != null) {
        return false;
      }
      return _dueFilter == null ||
          matchesTaskDueFilter(
            task.plan,
            task.workflowKey,
            _dueFilter!,
            DateTime.now(),
          );
    }
    if (_completedPeriod == null || _completedPeriod == _CompletedPeriod.all) {
      return true;
    }

    final completedAt = taskCompletedAt(task.plan, task.workflowKey)?.toLocal();
    if (completedAt == null) return false;
    final completedDay = DateUtils.dateOnly(completedAt);
    final range = _completedDateRange;
    if (range == null) return false;
    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);
    return !completedDay.isBefore(start) && !completedDay.isAfter(end);
  }

  bool _matchesDeliveryFilters(TaskItem task) {
    if (_selectedClientId != null &&
        _clientFilterKey(task.plan) != _selectedClientId) {
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
      : widget.clientNames[plan.clientId] ?? 'No client linked';

  String _clientFilterKey(Plan plan) =>
      plan.clientId == _internalPracticeClientId ||
          widget.clientNames.containsKey(plan.clientId)
      ? plan.clientId
      : _unlinkedClientFilter;
}

class _TaskFilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _TaskFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: DropdownButtonFormField<T>(
      key: ValueKey((label, value)),
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

class CompletedPeriodControls<Period> extends StatelessWidget {
  final List<ButtonSegment<Period>> segments;
  final Period selected;
  final ValueChanged<Period> onSelected;
  final String dateLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSelectDates;

  const CompletedPeriodControls({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    required this.dateLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDates,
  });

  static const _iconStyle = ButtonStyle(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    minimumSize: WidgetStatePropertyAll(Size(24, 24)),
    maximumSize: WidgetStatePropertyAll(Size(24, 24)),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('completed-period-controls'),
    width: 650,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<Period>(
                  key: const ValueKey('completed-period-selector'),
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const WidgetStatePropertyAll(Size(0, 24)),
                    maximumSize: const WidgetStatePropertyAll(
                      Size(double.infinity, 24),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 4),
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.onSurface,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Theme.of(context).chipTheme.selectedColor ??
                                Theme.of(context).colorScheme.secondaryContainer
                          : Colors.transparent,
                    ),
                  ),
                  segments: segments,
                  selected: {selected},
                  onSelectionChanged: (selection) =>
                      onSelected(selection.single),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Select dates',
                iconSize: 20,
                style: _iconStyle,
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: onSelectDates,
              ),
            ],
          ),
        ),
        SizedBox(
          key: const ValueKey('completed-period-navigation'),
          height: 24,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous period',
                iconSize: 20,
                style: _iconStyle,
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrevious,
              ),
              Expanded(
                child: Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Next period',
                iconSize: 20,
                style: _iconStyle,
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TaskSummaryCard extends StatelessWidget {
  final String title;
  final int total;
  final Map<String, int> counts;
  final Widget? trailing;

  const _TaskSummaryCard({
    required this.title,
    required this.total,
    required this.counts,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title  $total',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
          );
          if (trailing == null) return summary;
          if (constraints.maxWidth >= 1000) {
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                Flexible(child: trailing!),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [summary, const SizedBox(height: 12), trailing!],
          );
        },
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
    if (isSalesTaskFeature(task.workflowKey) &&
        lockedAssigneeId != null &&
        clientName != 'No client linked') {
      await _openSalesRecord(context, ref);
      return;
    }
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

  Future<void> _openSalesRecord(BuildContext context, WidgetRef ref) async {
    if (clientName == 'No client linked') {
      await showDialog<void>(
        context: context,
        builder: (_) => TaskWorkflowDialog(
          task: task,
          clientName: clientName,
          ref: ref,
          staff: ref.read(allUsersProvider).valueOrNull ?? [],
          lockedAssigneeId: lockedAssigneeId,
        ),
      );
      return;
    }
    try {
      final customer =
          ref
              .read(clientsListProvider)
              .valueOrNull
              ?.where((client) => client.id == task.plan.clientId)
              .firstOrNull ??
          await ref.read(clientProvider(task.plan.clientId).future);
      if (customer == null) throw StateError('Customer not found.');
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => SalesRecordDialog(
          client: customer,
          plans: ref.read(visiblePlansProvider).valueOrNull ?? [task.plan],
          initialTask: (plan: task.plan, feature: task.workflowKey),
          allowDeletion: lockedAssigneeId == null,
          customerRecord: true,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open sales record: $error')),
        );
      }
    }
  }

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    bool isArchived,
  ) async {
    try {
      final updated = setTaskArchived(task.plan, task.workflowKey, isArchived);
      final service = ref.read(firestoreServiceProvider);
      ref
          .read(taskSavesProvider.notifier)
          .submit(
            desired: updated,
            previous: task.plan,
            label: task.displayText,
            workflowKey: task.workflowKey,
            lockedAssigneeId: lockedAssigneeId,
            persist: () => service.updatePlan(updated, previous: task.plan),
          );
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
      final updated = setTaskTimerRunning(
        task.plan,
        task.workflowKey,
        isRunning,
        actor: ref.read(currentUserProfileProvider).valueOrNull,
      );
      final service = ref.read(firestoreServiceProvider);
      ref
          .read(taskSavesProvider.notifier)
          .submit(
            desired: updated,
            previous: task.plan,
            label: task.displayText,
            workflowKey: task.workflowKey,
            lockedAssigneeId: lockedAssigneeId,
            persist: () => service.updatePlan(updated, previous: task.plan),
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
    final pendingSave = ref.watch(taskSavesProvider)[task.plan.id];
    final saveBlocked =
        pendingSave != null && pendingSave.phase != TaskSavePhase.confirmed;
    final staff = ref.watch(allUsersProvider).valueOrNull ?? const <AppUser>[];
    final activeCycle = currentTaskCycle(task.plan, task.workflowKey);
    final pendingReviewer =
        task.status == TaskStatus.draftCycle &&
            draftCycleStage(task.plan, task.workflowKey) ==
                DraftCycleStage.confirmation &&
            activeCycle['clientConfirmed'] != true
        ? activeCycle['reviewRequestedFrom']?.toString()
        : null;
    final cycleNumber = (activeCycle['cycle'] as num?)?.toInt();
    final assignee = taskAssigneeName(task.plan, task.workflowKey);
    final priority = taskPriority(task.plan, task.workflowKey);
    final startedAt = taskStartedAt(task.plan, task.workflowKey);
    final elapsed = taskElapsedTime(task.plan, task.workflowKey);
    final timerRunning = taskTimerIsRunning(task.plan, task.workflowKey);
    final dueAt = taskDueAt(task.plan, task.workflowKey);
    final dueState = _deliveryDueState(dueAt);
    final dates = taskCardDates(context, task.plan, task.workflowKey);
    final statusLabel = [
      if (assignee != null) assignee,
      if (cycleNumber != null) 'Draft $cycleNumber',
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
              if (pendingSave?.phase == TaskSavePhase.saving)
                const Chip(label: Text('Saving...')),
              if (pendingSave?.phase == TaskSavePhase.failed)
                const Chip(label: Text('Save failed - retry above')),
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
                  if (pendingReviewer == 'admin' || pendingReviewer == 'client')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pending_actions,
                            size: 16,
                            color: Colors.brown.shade800,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              pendingReviewer == 'admin'
                                  ? 'Waiting for admin approval'
                                  : 'Waiting for client approval',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.brown.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
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
                  if (pendingReviewer != 'admin' && pendingReviewer != 'client')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: task.isWorkflowCompleted
                            ? Colors.green.shade100
                            : Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        timerRunning && !task.isWorkflowCompleted
                            ? 'Working'
                            : task.status.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
                    if (statusLabel.isNotEmpty)
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
            '${dates.isEmpty ? '' : ' • $dates'}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSalesTaskFeature(task.workflowKey))
                IconButton(
                  tooltip: 'Sales record',
                  icon: const Icon(Icons.fact_check_outlined),
                  onPressed: saveBlocked
                      ? null
                      : () => _openSalesRecord(context, ref),
                ),
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
                  onPressed: saveBlocked
                      ? null
                      : () => _setTimerRunning(context, ref, !timerRunning),
                ),
              IconButton(
                tooltip: task.isArchived ? 'Restore task' : 'Archive task',
                icon: Icon(
                  task.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                onPressed: saveBlocked
                    ? null
                    : () => _setArchived(context, ref, !task.isArchived),
              ),
              const Icon(Icons.edit_note_outlined),
            ],
          ),
          onTap: saveBlocked ? null : () => _openWorkflow(context, ref, staff),
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
    TaskStatus.started => 'Started',
    TaskStatus.draftCycle => 'Draft cycle',
    TaskStatus.completed => 'Completed',
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

class TaskWorkflowDialog extends ConsumerStatefulWidget {
  final TaskItem task;
  final String clientName;
  final WidgetRef ref;
  final List<AppUser> staff;
  final String? lockedAssigneeId;
  final String? lockedAssigneeName;
  final bool allowCompletion;
  final Map<String, String> retainedEdits;
  final bool replaceFailedSave;

  const TaskWorkflowDialog({
    required this.task,
    required this.clientName,
    required this.ref,
    required this.staff,
    this.lockedAssigneeId,
    this.lockedAssigneeName,
    this.allowCompletion = true,
    this.retainedEdits = const {},
    this.replaceFailedSave = false,
  });

  @override
  ConsumerState<TaskWorkflowDialog> createState() => _TaskWorkflowDialogState();
}

class _TaskWorkflowDialogState extends ConsumerState<TaskWorkflowDialog> {
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

  bool get _readOnly => widget.task.status == TaskStatus.completed;

  bool get _canComplete =>
      widget.allowCompletion &&
      widget.lockedAssigneeId == null &&
      (ref
              .read(currentUserProfileProvider)
              .valueOrNull
              ?.canAccessPanel('tasks') ??
          false);

  Map<String, dynamic>? get _currentDraft => _drafts.isEmpty
      ? null
      : _drafts.reduce(
          (left, right) =>
              ((left['cycle'] as num?)?.toInt() ?? 0) >
                  ((right['cycle'] as num?)?.toInt() ?? 0)
              ? left
              : right,
        );

  String? get _pendingReviewer {
    final draft = _currentDraft;
    if (_status != TaskStatus.draftCycle ||
        _draftStage != DraftCycleStage.confirmation ||
        draft == null ||
        draft['clientConfirmed'] == true) {
      return null;
    }
    return draft['reviewRequestedFrom']?.toString();
  }

  bool get _canSubmitForAdminReview =>
      _canComplete ||
      ((ref
                  .read(currentUserProfileProvider)
                  .valueOrNull
                  ?.canAccessPanel('myTasks') ??
              false) &&
          ref.read(currentStaffIdsProvider).contains(_assignedTo));

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
    final subcategories =
        planFeatureSubcategories[_category] ?? const <String>[];
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

  Future<void> _save({String? reviewAction}) async {
    if (_saving) return;
    if (reviewAction != null &&
        (reviewAction == 'admin' ? !_canSubmitForAdminReview : !_canComplete)) {
      setState(() => _error = 'You do not have access to this review action.');
      return;
    }
    if (reviewAction != null &&
        reviewAction != 'restore' &&
        _assignedTo == null) {
      setState(() => _error = 'Assign the task before requesting approval.');
      return;
    }
    if (reviewAction == 'restore' &&
        (widget.task.status != TaskStatus.completed ||
            _status != TaskStatus.completed)) {
      setState(() => _error = 'Only completed tasks can be restored.');
      return;
    }
    if (reviewAction == 'complete' && _pendingReviewer != 'client') {
      setState(
        () => _error = 'Send to the client for approval before completing.',
      );
      return;
    }
    if (_status == TaskStatus.completed &&
        widget.task.status != TaskStatus.completed &&
        !_canComplete) {
      setState(() => _error = 'Complete tasks from the Assign Tasks panel.');
      return;
    }
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
        reviewAction != 'restore' &&
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
        ? setTaskStatus(
            renamedPlan,
            workflowKey,
            _status,
            actor: ref.read(currentUserProfileProvider).valueOrNull,
          )
        : replaceTaskWorkflowCycles(
            renamedPlan,
            workflowKey,
            _drafts,
            actor: ref.read(currentUserProfileProvider).valueOrNull,
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
                : widget.lockedAssigneeName ??
                      taskAssigneeName(
                        widget.task.plan,
                        widget.task.workflowKey,
                      ))
          : (assignedUser.name.isEmpty
                ? assignedUser.email
                : assignedUser.name),
      priority: _priority,
      actor: ref.read(currentUserProfileProvider).valueOrNull,
    );
    var updated = updateTaskManagementDetails(
      assigned,
      workflowKey,
      dueAt: _dueAt,
      internalNotes: _internalNotesController.text,
      actor: ref.read(currentUserProfileProvider).valueOrNull,
    );
    try {
      updated = switch (reviewAction) {
        'admin' || 'client' => submitTaskForReview(
          updated,
          workflowKey,
          reviewer: reviewAction!,
          actor: ref.read(currentUserProfileProvider).valueOrNull,
        ),
        'changes' => createNextDraftCycle(
          updated,
          workflowKey,
          actor: ref.read(currentUserProfileProvider).valueOrNull,
        ),
        'complete' => completeReviewedTask(
          updated,
          workflowKey,
          actor: ref.read(currentUserProfileProvider).valueOrNull,
        ),
        'restore' => restoreCompletedTask(
          widget.task.plan,
          widget.task.workflowKey,
        ),
        null => updated,
        _ => throw ArgumentError.value(reviewAction, 'reviewAction'),
      };
      final service = widget.ref.read(firestoreServiceProvider);
      final submitted = updated;
      final previous = widget.task.plan;
      ref
          .read(taskSavesProvider.notifier)
          .submit(
            desired: submitted,
            previous: previous,
            label: title,
            workflowKey: widget.task.workflowKey,
            lockedAssigneeId: widget.lockedAssigneeId,
            replaceFailed: widget.replaceFailedSave,
            persist: () => service.updatePlan(submitted, previous: previous),
          );
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
    if (!_canComplete) return;
    if (_drafts.isNotEmpty) {
      setState(
        () =>
            _error = 'Send this draft through admin and client approval first.',
      );
      return;
    }
    if (_pendingReviewer == 'admin' || _pendingReviewer == 'client') {
      setState(() => _error = 'Record client approval before completing.');
      return;
    }
    setState(() {
      _status = TaskStatus.completed;
      _confirmCurrentDraft();
    });
    await _save();
  }

  Future<void> _restore() async {
    final confirmation = TextEditingController();
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore completed task?'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Return this task to its previous stage and remove its '
                  'completion confirmation. Drafts, notes, assignment, and '
                  'progress are kept. The work timer stays paused.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmation,
                  autofocus: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Type RESTORE to confirm',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: confirmation,
            builder: (context, value, child) => FilledButton(
              onPressed: value.text == 'RESTORE'
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: const Text('Restore task'),
            ),
          ),
        ],
      ),
    );
    try {
      final confirmed = await Navigator.of(context).push(route);
      await route.completed;
      if (confirmed == true && mounted) await _save(reviewAction: 'restore');
    } finally {
      confirmation.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    if (!_canComplete && (profile?.canAccessPanel('myTasks') ?? false)) {
      ref.watch(currentStaffIdsProvider);
    }
    final orderedDrafts = [..._drafts]
      ..sort((a, b) {
        final aNumber = (a['cycle'] as num?)?.toInt() ?? 0;
        final bNumber = (b['cycle'] as num?)?.toInt() ?? 0;
        return bNumber.compareTo(aNumber);
      });
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Task Details')),
          if (profile?.isAdmin == true && widget.lockedAssigneeId == null)
            IconButton(
              tooltip: 'Delete task',
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      final deleted = await confirmTaskDeletion(
                        context,
                        ref,
                        planId: widget.task.plan.id,
                        feature: widget.task.rawFeature,
                      );
                      if (deleted && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RetainedTaskEdits(edits: widget.retainedEdits),
              TextField(
                controller: _titleController,
                readOnly: _readOnly,
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
                onChanged: _readOnly
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _category = value;
                            final options =
                                planFeatureSubcategories[value] ??
                                const <String>[];
                            _subcategory = options.firstOrNull;
                          });
                        }
                      },
              ),
              if ((planFeatureSubcategories[_category] ?? const [])
                  .isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('edit-subcategory-$_category'),
                  initialValue: _subcategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subcategory'),
                  items: [
                    for (final subcategory
                        in planFeatureSubcategories[_category]!)
                      DropdownMenuItem(
                        value: subcategory,
                        child: Text(subcategory),
                      ),
                  ],
                  onChanged: _readOnly
                      ? null
                      : (subcategory) =>
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
              if (widget.lockedAssigneeId == null &&
                  widget.clientName == 'No client linked')
                UnlinkedPlanRepair(plan: widget.task.plan),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _assignedTo,
                      isExpanded: true,
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
                      onChanged: !_readOnly && widget.lockedAssigneeId == null
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
                      isExpanded: true,
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
                      onChanged: _readOnly
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _priority = value);
                              }
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
              if (_pendingReviewer == 'admin' ||
                  _pendingReviewer == 'client') ...[
                const SizedBox(height: 10),
                Text(
                  _pendingReviewer == 'admin'
                      ? 'Waiting for admin approval'
                      : 'Waiting for client approval',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
              if (_canComplete && _pendingReviewer == 'admin') ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _save(reviewAction: 'changes'),
                      icon: const Icon(Icons.reply_outlined),
                      label: const Text('Request changes'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TaskTrackingSection(
                plan: widget.task.plan,
                workflowKey: widget.task.workflowKey,
              ),
              OutlinedButton.icon(
                onPressed: _readOnly ? null : _pickDueDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dueAt == null
                      ? 'Set due date'
                      : 'Due ${MaterialLocalizations.of(context).formatShortDate(_dueAt!)}',
                ),
              ),
              if (!_readOnly && _dueAt != null)
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
                readOnly: _readOnly,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Internal project notes',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Drafts',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (!_readOnly)
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
                                  'createdAt': DateTime.now()
                                      .toUtc()
                                      .toIso8601String(),
                                  if (profile != null)
                                    'createdBy': {
                                      'uid': profile.uid,
                                      'name': profile.name.isEmpty
                                          ? profile.email
                                          : profile.name,
                                    },
                                  'status': TaskStatus.draftCycle.name,
                                  'draftStage':
                                      DraftCycleStage.instructions.name,
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
                            if (!_readOnly && widget.lockedAssigneeId == null)
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
                          readOnly: _readOnly,
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
                          readOnly: _readOnly,
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
          child: Text(_readOnly ? 'Close' : 'Cancel'),
        ),
        if (_canComplete &&
            widget.task.status == TaskStatus.completed &&
            _status == TaskStatus.completed)
          OutlinedButton.icon(
            onPressed: _saving ? null : _restore,
            icon: const Icon(Icons.undo),
            label: const Text('Restore previous stage'),
          ),
        if (_canSubmitForAdminReview &&
            _status != TaskStatus.completed &&
            _pendingReviewer != 'admin' &&
            _pendingReviewer != 'client')
          OutlinedButton(
            onPressed: _saving || _assignedTo == null
                ? null
                : () => _save(reviewAction: 'admin'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send_outlined, size: 18),
                SizedBox(width: 8),
                Flexible(child: Text('Send for admin approval')),
              ],
            ),
          ),
        if (_canComplete &&
            _status != TaskStatus.completed &&
            _pendingReviewer == 'admin')
          OutlinedButton(
            onPressed: _saving || _assignedTo == null
                ? null
                : () => _save(reviewAction: 'client'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send_outlined, size: 18),
                SizedBox(width: 8),
                Flexible(child: Text('Send to client for approval')),
              ],
            ),
          ),
        if (_canComplete && _pendingReviewer == 'client')
          OutlinedButton(
            onPressed: _saving ? null : () => _save(reviewAction: 'complete'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 18),
                SizedBox(width: 8),
                Flexible(child: Text('Client approved - move to Completed')),
              ],
            ),
          ),
        if (_canComplete &&
            _status != TaskStatus.completed &&
            _pendingReviewer == null &&
            _drafts.isEmpty)
          OutlinedButton.icon(
            onPressed: _saving || _assignedTo == null ? null : _complete,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete'),
          ),
        if (!_readOnly)
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
