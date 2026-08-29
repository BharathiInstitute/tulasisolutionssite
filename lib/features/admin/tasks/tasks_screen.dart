import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allPlansStreamProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/tasks',
      title: 'Tasks',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(allPlansStreamProvider),
        ),
      ],
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
            clientNames: {for (final client in clients) client.id: client.name},
          ),
        ),
      ),
    );
  }
}

class _TaskOverview extends StatefulWidget {
  final List<Plan> plans;
  final Map<String, String> clientNames;

  const _TaskOverview({required this.plans, required this.clientNames});

  @override
  State<_TaskOverview> createState() => _TaskOverviewState();
}

class _TaskOverviewState extends State<_TaskOverview> {
  String? _selectedCategory;
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<_TaskItem>>{};
    for (final plan in widget.plans) {
      for (final rawFeature in plan.features) {
        final category = parseFeature(rawFeature).category;
        final units = _contentUnitCount(parseFeature(rawFeature).text);
        if (units == null) {
          categories
              .putIfAbsent(category, () => [])
              .add(_TaskItem(rawFeature: rawFeature, plan: plan));
        } else {
          for (var unit = 1; unit <= units; unit++) {
            categories
                .putIfAbsent(category, () => [])
                .add(
                  _TaskItem(
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
    final completedCount = allItems
        .where((task) => task.isWorkflowCompleted)
        .length;
    final activeItems = allItems
        .where((task) => !task.isWorkflowCompleted)
        .toList();
    final totalTasks = activeItems.length;
    final totalClients = activeItems
        .map((task) => task.plan.clientId)
        .toSet()
        .length;
    final contentTotals = _contentTotals(activeItems);
    final visibleCategories = <String, List<_TaskItem>>{};
    for (final entry in categories.entries) {
      final visible = entry.value
          .where((task) => task.isWorkflowCompleted == _showCompleted)
          .toList();
      if (visible.isNotEmpty) visibleCategories[entry.key] = visible;
    }
    if (categories.isEmpty) {
      return const Center(child: Text('No tasks found in assigned plans'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryHeader(
          totalTasks: totalTasks,
          totalClients: totalClients,
          contentTotals: contentTotals,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text('Active (${allItems.length - completedCount})'),
              selected: !_showCompleted && _selectedCategory == null,
              onSelected: (_) => setState(() {
                _showCompleted = false;
                _selectedCategory = null;
              }),
            ),
            FilterChip(
              label: Text('Completed ($completedCount)'),
              selected: _showCompleted && _selectedCategory == null,
              onSelected: (_) => setState(() {
                _showCompleted = true;
                _selectedCategory = null;
              }),
            ),
            for (final category in visibleCategories.keys)
              FilterChip(
                label: Text(
                  '$category (${visibleCategories[category]!.length})',
                ),
                selected: _selectedCategory == category,
                onSelected: (_) => setState(() => _selectedCategory = category),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final selectedEntries = visibleCategories.entries.where(
              (entry) =>
                  _selectedCategory == null || entry.key == _selectedCategory,
            );
            final selectedTasks = selectedEntries
                .expand((entry) => entry.value)
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
                for (final entry in selectedEntries)
                  for (final task in entry.value)
                    _TaskRow(
                      task: task,
                      category: entry.key,
                      clientName:
                          widget.clientNames[task.plan.clientId] ??
                          'Unknown client',
                    ),
              ],
            );
          },
        ),
      ],
    );
  }

  Map<String, int> _contentTotals(Iterable<_TaskItem> items) {
    final totals = <String, int>{};
    for (final item in items) {
      if (item.unitTotal != null) {
        final text = parseFeature(item.rawFeature).text.toLowerCase();
        final match = RegExp(
          r'^(\d+)\s+(reels?|designs?|videos?)',
        ).firstMatch(text);
        if (match != null) {
          final key = match.group(2)!.replaceFirst(RegExp(r's$'), '');
          totals[key] = (totals[key] ?? 0) + 1;
        }
        continue;
      }
      final text = parseFeature(item.rawFeature).text.toLowerCase();
      final match = RegExp(
        r'^(\d+)\s+(reels?|designs?|videos?)',
      ).firstMatch(text);
      if (match != null) {
        final key = match.group(2)!.replaceFirst(RegExp(r's$'), '');
        totals[key] = (totals[key] ?? 0) + int.parse(match.group(1)!);
      }
    }
    return totals;
  }

  int? _contentUnitCount(String text) {
    final match = RegExp(
      r'^(\d+)\s+(reels?|designs?|videos?)',
      caseSensitive: false,
    ).firstMatch(text.trim());
    final count = int.tryParse(match?.group(1) ?? '');
    return count != null && count > 0 ? count : null;
  }
}

class _SummaryHeader extends StatelessWidget {
  final int totalTasks;
  final int totalClients;
  final Map<String, int> contentTotals;

  const _SummaryHeader({
    required this.totalTasks,
    required this.totalClients,
    required this.contentTotals,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryTile(
          label: 'Total tasks',
          value: '$totalTasks',
          icon: Icons.task_alt,
        ),
        _SummaryTile(
          label: 'Clients',
          value: '$totalClients',
          icon: Icons.people_outline,
        ),
        for (final entry in contentTotals.entries)
          _SummaryTile(
            label: '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
            value: '${entry.value}',
            icon: entry.key == 'reel'
                ? Icons.movie_outlined
                : entry.key == 'design'
                ? Icons.image_outlined
                : Icons.videocam_outlined,
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  final _TaskItem task;
  final String category;
  final String clientName;

  const _TaskRow({
    required this.task,
    required this.category,
    required this.clientName,
  });

  Future<void> _openWorkflow(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _TaskWorkflowDialog(task: task, clientName: clientName, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = task.displayText;
    final activeCycle = currentTaskCycle(task.plan, task.workflowKey);
    final cycleNumber = (activeCycle['cycle'] as num?)?.toInt();
    final statusLabel = cycleNumber == null
        ? task.status.label
        : 'Instructions $cycleNumber • ${task.status.label}';
    final showStatus = !task.isWorkflowCompleted;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        task.isWorkflowCompleted ? Icons.verified : Icons.assignment_outlined,
        color: task.isWorkflowCompleted ? Colors.green : Colors.orange,
      ),
      title: Row(
        children: [
          Expanded(child: Text(text)),
          if (showStatus)
            Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
        ],
      ),
      subtitle: Text('$category • Client: $clientName'),
      trailing: const Icon(Icons.edit_note_outlined),
      onTap: () => _openWorkflow(context, ref),
    );
  }
}

class _TaskItem {
  final String rawFeature;
  final Plan plan;
  final int? unitIndex;
  final int? unitTotal;

  const _TaskItem({
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

extension _TaskStatusLabels on TaskStatus {
  String get label => switch (this) {
    TaskStatus.draft => 'Instructions',
    TaskStatus.inProgress => 'In working',
    TaskStatus.awaitingConfirmation => 'Waiting for confirmation',
    TaskStatus.completed => 'Completed',
  };
}

class _TaskWorkflowDialog extends StatefulWidget {
  final _TaskItem task;
  final String clientName;
  final WidgetRef ref;

  const _TaskWorkflowDialog({
    required this.task,
    required this.clientName,
    required this.ref,
  });

  @override
  State<_TaskWorkflowDialog> createState() => _TaskWorkflowDialogState();
}

class _TaskWorkflowDialogState extends State<_TaskWorkflowDialog> {
  late final TextEditingController _instructionsController;
  late final TextEditingController _updateController;
  late TaskStatus _status;
  late int _cycleNumber;
  late List<Map<String, dynamic>> _drafts;
  bool _saving = false;

  void _syncDraftsFromSelection() {
    final index = _drafts.indexWhere(
      (draft) => (draft['cycle'] as num?)?.toInt() == _cycleNumber,
    );
    if (index < 0) return;
    _drafts[index] = {
      ..._drafts[index],
      'cycle': _cycleNumber,
      'status': _status.name,
      'instructions': _instructionsController.text.trim(),
      'update': _updateController.text.trim(),
      'clientConfirmed': false,
    };
  }

  void _selectDraft(int cycleNumber) {
    final index = _drafts.indexWhere(
      (draft) => (draft['cycle'] as num?)?.toInt() == cycleNumber,
    );
    if (index < 0) return;
    final draft = _drafts[index];
    setState(() {
      _cycleNumber = cycleNumber;
      _status = TaskStatus.values.firstWhere(
        (status) => status.name == draft['status'],
        orElse: () => TaskStatus.draft,
      );
      _instructionsController.text = draft['instructions']?.toString() ?? '';
      _updateController.text = draft['update']?.toString() ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    _drafts = taskCycles(widget.task.plan, widget.task.workflowKey)
        .where((draft) => (draft['cycle'] as num?) != null)
        .map((draft) => Map<String, dynamic>.from(draft))
        .toList();
    _cycleNumber = _drafts.isEmpty
        ? 1
        : (_drafts.last['cycle'] as num?)?.toInt() ?? 1;
    _status = widget.task.status;
    if (_drafts.isEmpty) {
      _drafts = [
        {
          'cycle': 1,
          'status': _status.name,
          'instructions': taskText(
            widget.task.plan,
            widget.task.workflowKey,
            'instructions',
          ),
          'update': taskText(
            widget.task.plan,
            widget.task.workflowKey,
            'update',
          ),
          'clientConfirmed': false,
        },
      ];
    }
    final activeCycle = currentTaskCycle(
      widget.task.plan,
      widget.task.workflowKey,
    );
    _cycleNumber =
        (activeCycle['cycle'] as num?)?.toInt() ??
        (_drafts.first['cycle'] as num?)?.toInt() ??
        1;
    final selectedDraft = _drafts.firstWhere(
      (draft) => (draft['cycle'] as num?)?.toInt() == _cycleNumber,
      orElse: () => _drafts.first,
    );
    _status = TaskStatus.values.firstWhere(
      (status) => status.name == selectedDraft['status'],
      orElse: () => TaskStatus.draft,
    );
    _instructionsController = TextEditingController(
      text: taskText(widget.task.plan, widget.task.workflowKey, 'instructions'),
    );
    _updateController = TextEditingController(
      text: taskText(widget.task.plan, widget.task.workflowKey, 'update'),
    );
    _instructionsController.text =
        selectedDraft['instructions']?.toString() ?? '';
    _updateController.text = selectedDraft['update']?.toString() ?? '';
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _updateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _syncDraftsFromSelection();
    final workflow = widget.task.plan.taskWorkflow[widget.task.workflowKey];
    final confirmed = workflow?['clientConfirmed'] == true;
    if (_status == TaskStatus.completed && !confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client confirmation is required first')),
      );
      return;
    }
    setState(() => _saving = true);
    final updated = replaceTaskWorkflowCycles(
      widget.task.plan,
      widget.task.workflowKey,
      _drafts,
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

  @override
  Widget build(BuildContext context) {
    final orderedDrafts = [..._drafts]
      ..sort((a, b) {
        final aNumber = (a['cycle'] as num?)?.toInt() ?? 0;
        final bNumber = (b['cycle'] as num?)?.toInt() ?? 0;
        return bNumber.compareTo(aNumber);
      });

    return AlertDialog(
      title: Text(widget.task.displayText),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Client: ${widget.clientName}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Current: Instructions $_cycleNumber • ${_status.label}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        final nextCycle = orderedDrafts.isEmpty
                            ? 1
                            : ((orderedDrafts.first['cycle'] as num?)
                                          ?.toInt() ??
                                      0) +
                                  1;
                        final draft = {
                          'cycle': nextCycle,
                          'status': TaskStatus.draft.name,
                          'instructions': '',
                          'update': '',
                          'clientConfirmed': false,
                        };
                        _drafts.insert(0, draft);
                        _cycleNumber = nextCycle;
                        _status = TaskStatus.draft;
                        _instructionsController.clear();
                        _updateController.clear();
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text('New draft • ${_status.label}'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final status in [
                    TaskStatus.draft,
                    TaskStatus.inProgress,
                    TaskStatus.awaitingConfirmation,
                  ])
                    ChoiceChip(
                      label: Text(status.label),
                      selected: _status == status,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      onSelected: (_) {
                        setState(() {
                          _status = status;
                          _syncDraftsFromSelection();
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderedDrafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final draft = orderedDrafts[index];
                  final draftNumber = (draft['cycle'] as num?)?.toInt() ?? 1;
                  final isSelected = _cycleNumber == draftNumber;
                  final draftStatus = TaskStatus.values.firstWhere(
                    (status) => status.name == draft['status'],
                    orElse: () => TaskStatus.draft,
                  );
                  final stageLabel = draftStatus.label;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              _selectDraft(draftNumber);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Instructions $draftNumber',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        stageLabel,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit draft',
                          onPressed: () => _selectDraft(draftNumber),
                          icon: const Icon(Icons.edit_outlined),
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
                                _cycleNumber = 1;
                                _status = TaskStatus.draft;
                                _instructionsController.clear();
                                _updateController.clear();
                                return;
                              }
                              final nextSelection =
                                  _drafts
                                      .map(
                                        (item) =>
                                            (item['cycle'] as num?)?.toInt(),
                                      )
                                      .whereType<int>()
                                      .toList()
                                    ..sort();
                              final fallback = nextSelection.last;
                              _cycleNumber = fallback;
                              _selectDraft(fallback);
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _instructionsController,
                maxLines: 4,
                onChanged: (_) {
                  _syncDraftsFromSelection();
                },
                decoration: const InputDecoration(
                  labelText: 'Client instructions',
                  hintText: 'What should the client provide or approve?',
                ),
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
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save update'),
        ),
      ],
    );
  }
}
