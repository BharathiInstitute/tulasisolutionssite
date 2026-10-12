import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/tasks/task_save_controller.dart';
import '../../../core/tasks/task_workflow.dart';
import '../../../core/widgets/retained_task_edits.dart';
import '../client_profile/assign_plan_dialog.dart';
import 'sales_record_dialog.dart';
import 'tasks_screen.dart';

Future<void> showRetainedTaskEdits(
  BuildContext context,
  TaskSave save,
) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Retained unsaved edits'),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: save.retainedText.isEmpty
            ? const Text(
                'No text was entered for this action. Reopen the latest task to review its current status.',
              )
            : RetainedTaskEdits(edits: save.retainedText, latestLoaded: false),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);

Future<void> reopenLatestTaskSave(
  BuildContext context,
  WidgetRef ref,
  TaskSave save,
) async {
  final controller = ref.read(taskSavesProvider.notifier);
  final service = ref.read(firestoreServiceProvider);
  try {
    final latest = await service
        .getPlanOnce(save.desired.id)
        .timeout(const Duration(seconds: 20));
    if (!context.mounted || !controller.mounted) return;
    controller.recordFreshPlan(save.desired.id, latest);
    if (latest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This plan no longer exists. Your unsaved text is still available.',
          ),
        ),
      );
      await showRetainedTaskEdits(context, save);
      return;
    }
    final client = await service
        .getClient(latest.clientId)
        .timeout(const Duration(seconds: 20));
    if (!context.mounted || !controller.mounted) return;
    if (client == null) throw StateError('This customer no longer exists.');
    final profile = await ref
        .read(currentUserProfileProvider.future)
        .timeout(const Duration(seconds: 20));
    if (!context.mounted || !controller.mounted) return;
    if (profile == null) throw StateError('Sign in before reopening the task.');
    final key = save.workflowKey;
    if (key == null) {
      if (!profile.canAccessPanel('plans') &&
          !profile.canAccessPanel('tasks')) {
        throw StateError('Plan editing access is required.');
      }
      final List<PlanTemplate> templates =
          ref.read(planTemplatesProvider).valueOrNull ??
          (await ref
              .read(planTemplatesProvider.future)
              .timeout(const Duration(seconds: 20)));
      if (!context.mounted || !controller.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AssignPlanDialog(
          clients: [client],
          templates: templates,
          existing: latest,
          retainedEdits: save.retainedText,
          replaceFailedSave: true,
        ),
      );
      return;
    }
    final baseline = save.previous ?? save.desired;
    final candidates =
        baseline.features
            .where((feature) => key == feature || key.startsWith('$feature#'))
            .toList()
          ..sort((left, right) => right.length.compareTo(left.length));
    final raw = candidates.firstOrNull;
    if (raw == null) {
      throw StateError(
        'The original task could not be identified. Your text is retained.',
      );
    }
    final original = baseline.taskForFeature(raw);
    final current = latest.tasks
        .where((task) => task.id == original?.id)
        .firstOrNull;
    final feature = current?.feature ?? raw;
    if (!latest.features.contains(feature)) {
      throw StateError('This task no longer exists. Your text is retained.');
    }
    final unitIndex = key == raw
        ? null
        : int.parse(key.substring(raw.length + 1));
    final currentKey = taskKey(feature, unitIndex);
    final assignee = taskAssigneeId(latest, currentKey);
    final personal =
        save.lockedAssigneeId != null || !profile.canAccessPanel('tasks');
    if (personal && !ref.read(currentStaffIdsProvider).contains(assignee)) {
      throw StateError(
        'This task is no longer assigned to you. Your text is retained.',
      );
    }
    if (save.refreshClientId != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => SalesRecordDialog(
          client: client,
          plans: [latest],
          initialTask: (plan: latest, feature: feature),
          allowDeletion: !personal,
          retainedEdits: save.retainedText,
          replaceFailedSave: true,
        ),
      );
    } else {
      final List<AppUser> staff =
          ref.read(allUsersProvider).valueOrNull ??
          (await ref
              .read(allUsersProvider.future)
              .timeout(const Duration(seconds: 20)));
      if (!context.mounted || !controller.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => TaskWorkflowDialog(
          task: TaskItem(
            rawFeature: feature,
            plan: latest,
            unitIndex: unitIndex,
          ),
          clientName: client.name,
          ref: ref,
          staff: staff,
          lockedAssigneeId: personal ? assignee : null,
          retainedEdits: save.retainedText,
          replaceFailedSave: true,
        ),
      );
    }
  } catch (error) {
    if (context.mounted && controller.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not reopen latest task: $error. Your unsaved edits are retained.',
          ),
        ),
      );
    }
  }
}
