import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final currentUser = ref.watch(firebaseAuthServiceProvider).getCurrentUser();
    final plansAsync = ref.watch(allPlansStreamProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/my-tasks',
      title: 'My Tasks',
      body: currentUser == null
          ? const Center(child: Text('No tasks assigned yet'))
          : plansAsync.when(
              loading: () => const LoadingWidget(),
              error: (error, stackTrace) => CustomErrorWidget(
                message: 'Error loading your tasks: $error',
              ),
              data: (plans) => _ClientTaskList(
                plans: plans,
                assigneeId: currentUser.uid,
              ),
            ),
    );
  }
}

class _ClientTaskList extends StatefulWidget {
  final List<Plan> plans;
  final String? assigneeId;

  const _ClientTaskList({
    required this.plans,
    this.assigneeId,
  });

  @override
  State<_ClientTaskList> createState() => _ClientTaskListState();
}

class _ClientTaskListState extends State<_ClientTaskList> {
  String? _selectedCategory;
  bool? _completedFilter = false;

  @override
  Widget build(BuildContext context) {
    final rows = <_ClientTaskItem>[];
    for (final plan in widget.plans) {
      for (final raw in plan.features) {
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
            if (taskAssigneeId(plan, item.key) == widget.assigneeId) {
              rows.add(item);
            }
          }
        } else {
          final item = _ClientTaskItem(plan: plan, rawFeature: raw);
          if (taskAssigneeId(plan, item.key) == widget.assigneeId) {
            rows.add(item);
          }
        }
      }
    }

    final activeRows = rows.where((row) => !row.archived).toList();
    final archivedRows = rows.where((row) => row.archived).toList();
    if (activeRows.isEmpty && archivedRows.isEmpty) {
      return const Center(child: Text('No tasks assigned yet'));
    }
    final categoryCounts = <String, int>{};
    for (final row in activeRows) {
      categoryCounts[row.category] = (categoryCounts[row.category] ?? 0) + 1;
    }
    final categories = categoryCounts.keys.toList()..sort();
    final completedCount = activeRows.where((row) => row.completed).length;
    final selectedCategory = categoryCounts.containsKey(_selectedCategory)
        ? _selectedCategory
        : null;
    final visibleRows = activeRows.where((row) {
      if (_completedFilter != null && row.completed != _completedFilter) {
        return false;
      }
      return selectedCategory == null || row.category == selectedCategory;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in categories)
              FilterChip(
                label: Text('$category (${categoryCounts[category]})'),
                selected: selectedCategory == category,
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = selectedCategory == category
                        ? null
                        : category;
                    _completedFilter = false;
                  });
                },
              ),
            FilterChip(
              label: Text('Completed ($completedCount)'),
              selected: _completedFilter == true,
              onSelected: (selected) => setState(() {
                _completedFilter = selected ? true : false;
                if (selected) _selectedCategory = null;
              }),
            ),
            FilterChip(
              label: Text('All (${activeRows.length})'),
              selected: selectedCategory == null && _completedFilter == null,
              onSelected: (_) => setState(() {
                _selectedCategory = null;
                _completedFilter = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < visibleRows.length; index++) ...[
          TaskRow(
            task: TaskItem(
              rawFeature: visibleRows[index].rawFeature,
              plan: visibleRows[index].plan,
              unitIndex: visibleRows[index].unitIndex,
              unitTotal: visibleRows[index].unitTotal,
            ),
            category: visibleRows[index].category,
            clientName: 'My task',
            lockedAssigneeId: widget.assigneeId,
          ),
          if (index < visibleRows.length - 1) const SizedBox(height: 2),
        ],
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
                    clientName: 'My task',
                    lockedAssigneeId: widget.assigneeId,
                  ),
            ],
          ),
        ),
      ],
    );
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
  String get category => parseFeature(rawFeature).category;
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
