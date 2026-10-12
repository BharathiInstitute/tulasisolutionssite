import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class MyAssignedTasksScreen extends ConsumerWidget {
  const MyAssignedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffIds = ref.watch(currentStaffIdsProvider);
    final plansAsync = ref.watch(visiblePlansProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/my-tasks',
      title: 'My Tasks',
      floatingActionButton: staffIds.isEmpty
          ? null
          : plansAsync.maybeWhen(
              data: (plans) => FloatingActionButton(
                tooltip: 'Create my task',
                onPressed: () async {
                  try {
                    final clients = await ref.read(clientsListProvider.future);
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (_) => CustomTaskDialog(
                        plans: plans,
                        clients: clients,
                        staff: const [],
                        selfAssignOnly: true,
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open task creation: $error'),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.add_task_outlined),
              ),
              orElse: () => null,
            ),
      body: staffIds.isEmpty
          ? const _ClientTaskList(
              plans: [],
              assigneeIds: [],
              completedOnly: false,
            )
          : plansAsync.when(
              loading: () => const LoadingWidget(),
              error: (error, stackTrace) => CustomErrorWidget(
                message: 'Error loading your tasks: $error',
                onRetry: () => ref.invalidate(allPlansStreamProvider),
              ),
              data: (plans) => _ClientTaskList(
                plans: plans,
                assigneeIds: staffIds,
                completedOnly: false,
                canOpenLeads:
                    ref
                        .watch(currentUserProfileProvider)
                        .valueOrNull
                        ?.canAccessPanel('leads') ==
                    true,
              ),
            ),
    );
  }
}

class MyCompletedTasksScreen extends ConsumerWidget {
  const MyCompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffIds = ref.watch(currentStaffIdsProvider);
    final plansAsync = ref.watch(visiblePlansProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/my-completed-tasks',
      title: 'My Completed Tasks',
      body: staffIds.isEmpty
          ? const Center(child: Text('No completed tasks yet'))
          : plansAsync.when(
              loading: () => const LoadingWidget(),
              error: (error, stackTrace) => CustomErrorWidget(
                message: 'Error loading your completed tasks: $error',
                onRetry: () => ref.invalidate(allPlansStreamProvider),
              ),
              data: (plans) => _ClientTaskList(
                plans: plans,
                assigneeIds: staffIds,
                completedOnly: true,
                canOpenLeads:
                    ref
                        .watch(currentUserProfileProvider)
                        .valueOrNull
                        ?.canAccessPanel('leads') ==
                    true,
              ),
            ),
    );
  }
}

class _ClientTaskList extends ConsumerStatefulWidget {
  final List<Plan> plans;
  final List<String> assigneeIds;
  final bool completedOnly;
  final bool canOpenLeads;

  const _ClientTaskList({
    required this.plans,
    required this.assigneeIds,
    required this.completedOnly,
    this.canOpenLeads = false,
  });

  @override
  ConsumerState<_ClientTaskList> createState() => _ClientTaskListState();
}

enum _MyCompletedPeriod { all, day, week, month, custom }

class _ClientTaskListState extends ConsumerState<_ClientTaskList> {
  String? _selectedCategory;
  TaskDueFilter? _dueFilter;
  _MyCompletedPeriod? _completedPeriod;
  DateTimeRange? _customCompletedRange;
  DateTime _completedPeriodAnchor = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.completedOnly) _completedPeriod = _MyCompletedPeriod.all;
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(taskClientsProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const LoadingWidget(),
          error: (error, stackTrace) => CustomErrorWidget(
            message: 'Error loading task clients: $error',
            onRetry: () {
              ref.invalidate(clientsListProvider);
              ref.invalidate(taskClientsProvider);
            },
          ),
          data: (clients) => _buildTasks(clients),
        );
  }

  Widget _buildTasks(List<Client> clients) {
    final clientNames = {for (final client in clients) client.id: client.name};
    String clientName(Plan plan) => plan.clientId == '__internal_practice__'
        ? 'Practice (Internal)'
        : clientNames[plan.clientId] ?? 'No client linked';
    final rows = <_ClientTaskItem>[];
    for (final plan in widget.plans) {
      for (final raw in plan.features) {
        if (!widget.completedOnly && isSalesTaskFeature(raw)) continue;
        final text = parseFeature(raw).text;
        final match = RegExp(
          r'^(\d+)\s+(reels?|designs?|videos?)',
          caseSensitive: false,
        ).firstMatch(text);
        final total = int.tryParse(match?.group(1) ?? '');
        if (total != null && total > 0) {
          for (var i = 1; i <= total; i++) {
            final item = _ClientTaskItem(
              plan: plan,
              rawFeature: raw,
              unitIndex: i,
              unitTotal: total,
            );
            if (widget.assigneeIds.contains(taskAssigneeId(plan, item.key))) {
              rows.add(item);
            }
          }
        } else {
          final item = _ClientTaskItem(plan: plan, rawFeature: raw);
          if (widget.assigneeIds.contains(taskAssigneeId(plan, item.key))) {
            rows.add(item);
          }
        }
      }
    }

    final activeRows = rows.where((row) => !row.archived).toList();
    final archivedRows = rows.where((row) => row.archived).toList();
    if (widget.completedOnly && activeRows.isEmpty && archivedRows.isEmpty) {
      return const Center(child: Text('No tasks assigned yet'));
    }
    final modeRows = activeRows
        .where((row) => row.completed == widget.completedOnly)
        .toList();
    final categoryCounts = <String, int>{};
    for (final row in modeRows) {
      categoryCounts[row.category] = (categoryCounts[row.category] ?? 0) + 1;
    }
    final categories = categoryCounts.keys.toList()..sort();
    final selectedCategory = categoryCounts.containsKey(_selectedCategory)
        ? _selectedCategory
        : null;
    final categoryRows = modeRows
        .where(_matchesCompletedPeriod)
        .where(
          (row) => selectedCategory == null || row.category == selectedCategory,
        )
        .toList();
    final now = DateTime.now();
    final visibleRows = categoryRows
        .where(
          (row) =>
              widget.completedOnly ||
              _dueFilter == null ||
              matchesTaskDueFilter(row.plan, row.key, _dueFilter!, now),
        )
        .toList();
    String dueLabel(TaskDueFilter filter) => switch (filter) {
      TaskDueFilter.todayAndOverdue => 'Today & Overdue',
      TaskDueFilter.upcoming => 'Upcoming',
      TaskDueFilter.unscheduled => 'Unscheduled',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.completedOnly)
              CompletedPeriodControls<_MyCompletedPeriod>(
                segments: const [
                  ButtonSegment(
                    value: _MyCompletedPeriod.all,
                    label: Text('All days'),
                  ),
                  ButtonSegment(
                    value: _MyCompletedPeriod.day,
                    label: Text('Day'),
                  ),
                  ButtonSegment(
                    value: _MyCompletedPeriod.week,
                    label: Text('Week'),
                  ),
                  ButtonSegment(
                    value: _MyCompletedPeriod.month,
                    label: Text('Month'),
                  ),
                  ButtonSegment(
                    value: _MyCompletedPeriod.custom,
                    label: Text('Custom'),
                  ),
                ],
                selected: _completedPeriod ?? _MyCompletedPeriod.all,
                onSelected: _selectCompletedPeriod,
                dateLabel: _completedPeriodLabel(context),
                onPrevious: _completedPeriod == _MyCompletedPeriod.all
                    ? null
                    : () => _moveCompletedPeriod(-1),
                onNext: _canMoveToNextCompletedPeriod
                    ? () => _moveCompletedPeriod(1)
                    : null,
                onSelectDates: () =>
                    _selectCompletedPeriod(_MyCompletedPeriod.custom),
              ),
            for (final category in categories)
              FilterChip(
                label: Text('$category (${categoryCounts[category]})'),
                selected: selectedCategory == category,
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = selectedCategory == category
                        ? null
                        : category;
                  });
                },
              ),
            FilterChip(
              label: Text('All (${modeRows.length})'),
              selected: selectedCategory == null,
              onSelected: (_) => setState(() {
                _selectedCategory = null;
              }),
            ),
            if (widget.completedOnly)
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
                onPressed:
                    selectedCategory == null &&
                        _completedPeriod == _MyCompletedPeriod.all
                    ? null
                    : () => setState(() {
                        _selectedCategory = null;
                        _completedPeriod = _MyCompletedPeriod.all;
                        _customCompletedRange = null;
                        _completedPeriodAnchor = DateUtils.dateOnly(
                          DateTime.now(),
                        );
                      }),
              ),
            if (!widget.completedOnly) ...[
              for (final filter in TaskDueFilter.values)
                FilterChip(
                  label: Text(
                    '${dueLabel(filter)} (${categoryRows.where((row) => matchesTaskDueFilter(row.plan, row.key, filter, now)).length})',
                  ),
                  selected: _dueFilter == filter,
                  onSelected: (selected) => setState(() {
                    _dueFilter = selected ? filter : null;
                  }),
                ),
              if (_dueFilter != null || selectedCategory != null)
                TextButton.icon(
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear filters'),
                  onPressed: () => setState(() {
                    _selectedCategory = null;
                    _dueFilter = null;
                  }),
                ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (!widget.completedOnly && visibleRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              activeRows.isEmpty && archivedRows.isEmpty
                  ? 'No tasks assigned yet'
                  : 'No tasks match the selected filters',
            ),
          ),
        for (var index = 0; index < visibleRows.length; index++) ...[
          TaskRow(
            task: TaskItem(
              rawFeature: visibleRows[index].rawFeature,
              plan: visibleRows[index].plan,
              unitIndex: visibleRows[index].unitIndex,
              unitTotal: visibleRows[index].unitTotal,
            ),
            category: visibleRows[index].category,
            clientName: clientName(visibleRows[index].plan),
            lockedAssigneeId: taskAssigneeId(
              visibleRows[index].plan,
              visibleRows[index].key,
            ),
          ),
          if (widget.canOpenLeads &&
              clientNames.containsKey(visibleRows[index].plan.clientId) &&
              isSalesTaskFeature(visibleRows[index].rawFeature))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Lead'),
                onPressed: () => context.push(
                  '/admin/leads/${Uri.encodeComponent(visibleRows[index].plan.clientId)}',
                ),
              ),
            ),
          if (index < visibleRows.length - 1) const SizedBox(height: 2),
        ],
        if (!widget.completedOnly) ...[
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text('Archived (${archivedRows.length})'),
              children: [
                if (archivedRows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text('No archived tasks'),
                  )
                else
                  for (final row in archivedRows)
                    TaskRow(
                      task: TaskItem(
                        rawFeature: row.rawFeature,
                        plan: row.plan,
                        unitIndex: row.unitIndex,
                        unitTotal: row.unitTotal,
                      ),
                      category: row.category,
                      clientName: clientName(row.plan),
                      lockedAssigneeId: taskAssigneeId(row.plan, row.key),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _selectCompletedPeriod(_MyCompletedPeriod? period) async {
    if (period != _MyCompletedPeriod.custom) {
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
      _completedPeriod = _MyCompletedPeriod.custom;
      _customCompletedRange = selectedRange;
    });
  }

  DateTimeRange? get _completedDateRange {
    final period = _completedPeriod;
    if (period == null) return null;
    return switch (period) {
      _MyCompletedPeriod.all => null,
      _MyCompletedPeriod.day => DateTimeRange(
        start: _completedPeriodAnchor,
        end: _completedPeriodAnchor,
      ),
      _MyCompletedPeriod.week => () {
        final start = _completedPeriodAnchor.subtract(
          Duration(days: _completedPeriodAnchor.weekday - DateTime.monday),
        );
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 6)),
        );
      }(),
      _MyCompletedPeriod.month => DateTimeRange(
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
      _MyCompletedPeriod.custom => _customCompletedRange,
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
        case _MyCompletedPeriod.all:
          return;
        case _MyCompletedPeriod.day:
          _completedPeriodAnchor = _completedPeriodAnchor.add(
            Duration(days: direction),
          );
        case _MyCompletedPeriod.week:
          _completedPeriodAnchor = _completedPeriodAnchor.add(
            Duration(days: 7 * direction),
          );
        case _MyCompletedPeriod.month:
          _completedPeriodAnchor = DateTime(
            _completedPeriodAnchor.year,
            _completedPeriodAnchor.month + direction,
          );
        case _MyCompletedPeriod.custom:
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
    if (_completedPeriod == _MyCompletedPeriod.week) {
      final start = localizations.formatShortMonthDay(range.start);
      final end = localizations.formatShortMonthDay(range.end);
      return '$start - $end';
    }
    if (_completedPeriod == _MyCompletedPeriod.month) {
      return localizations.formatMonthYear(range.start);
    }
    final start = localizations.formatShortDate(range.start);
    final end = localizations.formatShortDate(range.end);
    return start == end ? start : '$start - $end';
  }

  bool _matchesCompletedPeriod(_ClientTaskItem row) {
    if (!widget.completedOnly ||
        _completedPeriod == null ||
        _completedPeriod == _MyCompletedPeriod.all)
      return true;
    final completedAt = taskCompletedAt(row.plan, row.key)?.toLocal();
    final range = _completedDateRange;
    if (completedAt == null || range == null) return false;
    final completedDay = DateUtils.dateOnly(completedAt);
    return !completedDay.isBefore(range.start) &&
        !completedDay.isAfter(range.end);
  }
}

class _ClientTaskItem {
  final Plan plan;
  final String rawFeature;
  final int? unitIndex;
  final int? unitTotal;

  const _ClientTaskItem({
    required this.plan,
    required this.rawFeature,
    this.unitIndex,
    this.unitTotal,
  });

  String get key => taskKey(rawFeature, unitIndex);
  String get category => isSalesTaskFeature(rawFeature)
      ? salesFeatureCategory
      : parseFeature(rawFeature).category;
  Map<String, dynamic>? get workflow => plan.taskWorkflow[key];
  TaskStatus get status => taskStatus(plan, key);
  bool get completed => status == TaskStatus.completed;
  bool get archived => taskIsArchived(plan, key);
  String get text {
    final source = parseFeature(rawFeature).text;
    if (unitIndex == null || unitTotal == null) return source;
    final match = RegExp(
      r'^(\d+)\s+(reels?|designs?|videos?)',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) return source;
    final type = match.group(2)!;
    final singular = type.endsWith('s')
        ? type.substring(0, type.length - 1)
        : type;
    return '${singular[0].toUpperCase()}${singular.substring(1)} $unitIndex/$unitTotal';
  }
}
