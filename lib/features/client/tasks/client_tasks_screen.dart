import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class ClientTasksScreen extends ConsumerWidget {
  const ClientTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(firebaseAuthServiceProvider).getCurrentUser();
    final clientAsync = ref.watch(currentClientProvider);
    return AppShell(
      isAdmin: false,
      currentRoute: '/client/tasks',
      title: 'My Tasks',
      body: clientAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading your tasks: $error'),
        data: (client) {
          if (currentUser == null) {
            return const Center(child: Text('No tasks assigned yet'));
          }
          if (client == null) {
            return const Center(child: Text('Client profile not found'));
          }
          final plansAsync = ref.watch(plansProvider(client.id));
          return plansAsync.when(
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) =>
                CustomErrorWidget(message: 'Error loading tasks: $error'),
            data: (plans) => _ClientTaskList(plans: plans, isClientView: true),
          );
        },
      ),
    );
  }
}

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
                isStaffView: true,
              ),
            ),
    );
  }
}

class _ClientTaskList extends StatefulWidget {
  final List<Plan> plans;
  final String? assigneeId;
  final bool isStaffView;
  final bool isClientView;

  const _ClientTaskList({
    required this.plans,
    this.assigneeId,
    this.isStaffView = false,
    this.isClientView = false,
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
            if (widget.isClientView ||
                taskAssigneeId(plan, item.key) == widget.assigneeId) {
              rows.add(item);
            }
          }
        } else {
          final item = _ClientTaskItem(plan: plan, rawFeature: raw);
          if (widget.isClientView ||
              taskAssigneeId(plan, item.key) == widget.assigneeId) {
            rows.add(item);
          }
        }
      }
    }

    final activeRows = rows.where((row) => !row.archived).toList();
    final archivedRows = rows.where((row) => row.archived).toList();
    if (activeRows.isEmpty && (!widget.isStaffView || archivedRows.isEmpty)) {
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
          if (widget.isStaffView)
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
            )
          else
            _ClientTaskRow(
              item: visibleRows[index],
              isStaffView: false,
              isClientView: widget.isClientView,
            ),
          if (index < visibleRows.length - 1) const SizedBox(height: 2),
        ],
        if (widget.isStaffView) ...[
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

class _ClientTaskRow extends ConsumerWidget {
  final _ClientTaskItem item;
  final bool isStaffView;
  final bool isClientView;

  const _ClientTaskRow({
    required this.item,
    required this.isStaffView,
    required this.isClientView,
  });

  Future<void> _markSatisfied(BuildContext context, WidgetRef ref) async {
    try {
      final current = currentTaskCycle(item.plan, item.key);
      final cycleNumber = (current['cycle'] as num?)?.toInt() ?? 1;
      final confirmedPlan = updateTaskWorkflow(
        item.plan,
        item.key,
        status: TaskStatus.completed,
        instructions: current['instructions']?.toString() ?? '',
        update: current['update']?.toString() ?? '',
        clientConfirmed: true,
        cycleNumber: cycleNumber,
      );
      await ref.read(firestoreServiceProvider).updatePlan(confirmedPlan);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not confirm task: $error')),
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
      await ref
          .read(firestoreServiceProvider)
          .updatePlan(setTaskArchived(item.plan, item.key, isArchived));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArchived ? '${item.text} archived' : '${item.text} restored',
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
          .updatePlan(setTaskTimerRunning(item.plan, item.key, isRunning));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update timer: $error')),
        );
      }
    }
  }

  Future<void> _openTaskDetails(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(firebaseAuthServiceProvider).getCurrentUser();
    if (currentUser == null) return;
    final staff = ref.read(allUsersProvider).valueOrNull ?? const <AppUser>[];
    final currentStaff = staff
        .where((user) => user.uid == currentUser.uid)
        .firstOrNull;
    await showDialog<void>(
      context: context,
      builder: (_) => TaskWorkflowDialog(
        task: TaskItem(
          rawFeature: item.rawFeature,
          plan: item.plan,
          unitIndex: item.unitIndex,
          unitTotal: item.unitTotal,
        ),
        clientName: 'My task',
        ref: ref,
        staff: staff,
        lockedAssigneeId: currentUser.uid,
        lockedAssigneeName: currentStaff == null
            ? (currentUser.email ?? 'Myself')
            : (currentStaff.name.isEmpty
                  ? currentStaff.email
                  : currentStaff.name),
      ),
    );
  }

  Future<void> _requestAnotherDraft(BuildContext context, WidgetRef ref) async {
    try {
      final revisedPlan = createNextDraftCycle(item.plan, item.key);
      await ref.read(firestoreServiceProvider).updatePlan(revisedPlan);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request another draft: $error')),
        );
      }
    }
  }

  Future<void> _sendForReview(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit to admin review'),
        content: const Text(
          'Your admin will check this work before it is completed or sent to the client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final updated = submitTaskForReview(
        item.plan,
        item.key,
        reviewer: 'admin',
      );
      await ref.read(firestoreServiceProvider).updatePlan(updated);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit task for review: $error')),
        );
      }
    }
  }

  Future<void> _saveInstructions(
    BuildContext context,
    WidgetRef ref,
    int cycleNumber,
    String instructions,
  ) async {
    try {
      final updated = updateTaskCycleInstructions(
        item.plan,
        item.key,
        cycleNumber,
        instructions,
      );
      await ref.read(firestoreServiceProvider).updatePlan(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Instructions saved')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save instructions: $error')),
        );
      }
    }
  }

  Future<void> _saveWorkLink(
    BuildContext context,
    WidgetRef ref,
    int cycleNumber,
    String workLink,
  ) async {
    try {
      final updated = updateTaskCycleWorkLink(
        item.plan,
        item.key,
        cycleNumber,
        workLink,
      );
      await ref.read(firestoreServiceProvider).updatePlan(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Work link saved')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save work link: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = taskCycles(item.plan, item.key).reversed.toList();
    final currentCycle = drafts.isEmpty
        ? null
        : (drafts.first['cycle'] as num?)?.toInt();
    final currentDraftStage = draftCycleStage(item.plan, item.key);
    final startedAt = taskStartedAt(item.plan, item.key);
    final elapsed = taskElapsedTime(item.plan, item.key);
    final timerRunning = taskTimerIsRunning(item.plan, item.key);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          item.completed ? Icons.verified : Icons.assignment_outlined,
          color: item.completed ? Colors.green : Colors.orange,
        ),
        title: Row(
          children: [
            Expanded(child: Text(item.text)),
            if (isStaffView && !item.completed && !item.archived)
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
                onPressed: () => _setTimerRunning(context, ref, !timerRunning),
              ),
            if (isStaffView)
              IconButton(
                tooltip: 'Edit task details',
                icon: const Icon(Icons.edit_note_outlined),
                onPressed: () => _openTaskDetails(context, ref),
              ),
            if (isStaffView)
              IconButton(
                tooltip: item.archived ? 'Restore task' : 'Archive task',
                icon: Icon(
                  item.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                onPressed: () => _setArchived(context, ref, !item.archived),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${parseFeature(item.rawFeature).category} • ${timerRunning ? 'Working' : item.status.label}${item.status == TaskStatus.draftCycle ? ' • ${currentDraftStage.label}' : ''}',
            ),
            Text('${drafts.length} ${drafts.length == 1 ? 'draft' : 'drafts'}'),
            if (elapsed != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _TaskElapsedBadge(
                  initialElapsed: timerRunning
                      ? taskElapsedBeforeCurrentRun(item.plan, item.key)
                      : elapsed,
                  runningSince: timerRunning ? startedAt : null,
                ),
              ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (drafts.isEmpty)
                  const Text('No drafts available')
                else
                  for (var index = 0; index < drafts.length; index++) ...[
                    _ClientDraftPanel(
                      key: ValueKey(
                        'client-draft-${item.key}-${drafts[index]['cycle']}',
                      ),
                      draft: drafts[index],
                      isCurrent:
                          (drafts[index]['cycle'] as num?)?.toInt() ==
                          currentCycle,
                      canEdit:
                          (drafts[index]['cycle'] as num?)?.toInt() ==
                              currentCycle &&
                          item.status == TaskStatus.draftCycle &&
                          currentDraftStage == DraftCycleStage.instructions,
                      canUpdateWorkLink:
                          isStaffView &&
                          (drafts[index]['cycle'] as num?)?.toInt() ==
                              currentCycle,
                      onSave: (instructions) => _saveInstructions(
                        context,
                        ref,
                        (drafts[index]['cycle'] as num?)?.toInt() ?? 1,
                        instructions,
                      ),
                      onSaveWorkLink: (workLink) => _saveWorkLink(
                        context,
                        ref,
                        (drafts[index]['cycle'] as num?)?.toInt() ?? 1,
                        workLink,
                      ),
                    ),
                    if (index < drafts.length - 1) const SizedBox(height: 10),
                  ],
                if (item.status == TaskStatus.draftCycle &&
                    currentDraftStage == DraftCycleStage.confirmation &&
                    isClientView &&
                    (currentTaskCycle(
                              item.plan,
                              item.key,
                            )['reviewRequestedFrom']?.toString() ??
                            'client') ==
                        'client') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _requestAnotherDraft(context, ref),
                        child: const Text('Not satisfied'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _markSatisfied(context, ref),
                        child: const Text('Satisfied'),
                      ),
                    ],
                  ),
                ],
                if (isStaffView &&
                    !item.completed &&
                    currentDraftStage != DraftCycleStage.confirmation) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _sendForReview(context, ref),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Submit to admin review'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskElapsedBadge extends StatefulWidget {
  final Duration initialElapsed;
  final DateTime? runningSince;

  const _TaskElapsedBadge({
    required this.initialElapsed,
    required this.runningSince,
  });

  @override
  State<_TaskElapsedBadge> createState() => _TaskElapsedBadgeState();
}

class _TaskElapsedBadgeState extends State<_TaskElapsedBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTimer();
  }

  @override
  void didUpdateWidget(covariant _TaskElapsedBadge oldWidget) {
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
    final elapsed =
        widget.initialElapsed +
        (currentSegment.isNegative ? Duration.zero : currentSegment);
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 16),
        const SizedBox(width: 5),
        Text(
          '${widget.runningSince == null ? 'Total' : 'Elapsed'} $hours:$minutes:$seconds',
        ),
      ],
    );
  }
}

class _ClientDraftPanel extends StatefulWidget {
  final Map<String, dynamic> draft;
  final bool isCurrent;
  final bool canEdit;
  final bool canUpdateWorkLink;
  final Future<void> Function(String instructions) onSave;
  final Future<void> Function(String workLink) onSaveWorkLink;

  const _ClientDraftPanel({
    super.key,
    required this.draft,
    required this.isCurrent,
    required this.canEdit,
    required this.canUpdateWorkLink,
    required this.onSave,
    required this.onSaveWorkLink,
  });

  @override
  State<_ClientDraftPanel> createState() => _ClientDraftPanelState();
}

class _ClientDraftPanelState extends State<_ClientDraftPanel> {
  late final TextEditingController _controller;
  late final TextEditingController _workLinkController;
  bool _saving = false;
  bool _savingWorkLink = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.draft['instructions']?.toString() ?? '',
    );
    _workLinkController = TextEditingController(
      text: widget.draft['draftLink']?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _ClientDraftPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final instructions = widget.draft['instructions']?.toString() ?? '';
    if (instructions != oldWidget.draft['instructions']?.toString() &&
        instructions != _controller.text) {
      _controller.text = instructions;
    }
    final workLink = widget.draft['draftLink']?.toString() ?? '';
    if (workLink != oldWidget.draft['draftLink']?.toString() &&
        workLink != _workLinkController.text) {
      _workLinkController.text = workLink;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _workLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cycleNumber = (widget.draft['cycle'] as num?)?.toInt() ?? 1;
    final instructions = widget.draft['instructions']?.toString().trim() ?? '';
    final draftLink = widget.draft['draftLink']?.toString().trim() ?? '';
    final stage = _draftStageFromMap(widget.draft);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Draft $cycleNumber${widget.isCurrent ? ' • Current' : ''}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(stage.label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.canEdit)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Your instructions',
                      hintText: 'Add instructions for this draft',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Save instructions',
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await widget.onSave(_controller.text);
                          if (mounted) setState(() => _saving = false);
                        },
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
              ],
            )
          else ...[
            Text(
              'Client instructions',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            SelectableText(
              instructions.isEmpty ? 'No instructions provided' : instructions,
            ),
          ],
          if (widget.canUpdateWorkLink) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _workLinkController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Work link',
                      hintText: 'Link to the completed work',
                      prefixIcon: Icon(Icons.link_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Save work link',
                  onPressed: _savingWorkLink
                      ? null
                      : () async {
                          setState(() => _savingWorkLink = true);
                          await widget.onSaveWorkLink(_workLinkController.text);
                          if (mounted) setState(() => _savingWorkLink = false);
                        },
                  icon: _savingWorkLink
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
              ],
            ),
          ] else if (draftLink.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Work link', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            SelectableText(draftLink),
          ],
        ],
      ),
    );
  }
}

DraftCycleStage _draftStageFromMap(Map<String, dynamic> draft) {
  final raw = draft['draftStage']?.toString();
  for (final stage in DraftCycleStage.values) {
    if (stage.name == raw) return stage;
  }
  return switch (draft['status']?.toString()) {
    'inProgress' => DraftCycleStage.working,
    'awaitingConfirmation' => DraftCycleStage.confirmation,
    _ => DraftCycleStage.instructions,
  };
}

extension on TaskStatus {
  String get label => switch (this) {
    TaskStatus.notAssigned => 'Not assigned',
    TaskStatus.assigned => 'Assigned',
    TaskStatus.started => 'Start',
    TaskStatus.draftCycle => 'Draft cycle',
    TaskStatus.completed => 'Complete',
  };
}

extension on DraftCycleStage {
  String get label => switch (this) {
    DraftCycleStage.instructions => 'Instructions',
    DraftCycleStage.working => 'Working',
    DraftCycleStage.confirmation => 'Confirmation',
  };
}
