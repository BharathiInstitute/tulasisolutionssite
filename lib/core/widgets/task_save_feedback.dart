import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../tasks/task_save_controller.dart';
import '../../features/admin/tasks/task_save_recovery.dart';

class TaskSaveFeedback extends ConsumerStatefulWidget {
  const TaskSaveFeedback({super.key});

  @override
  ConsumerState<TaskSaveFeedback> createState() => _TaskSaveFeedbackState();
}

class _TaskSaveFeedbackState extends ConsumerState<TaskSaveFeedback> {
  final _opening = <String>{};

  Future<void> _reopen(TaskSave save) async {
    setState(() => _opening.add(save.desired.id));
    try {
      await reopenLatestTaskSave(context, ref, save);
    } finally {
      if (mounted) setState(() => _opening.remove(save.desired.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final saves = ref.watch(taskSavesProvider);
    final active = saves.values.where(
      (save) =>
          save.phase == TaskSavePhase.failed ||
          (save.phase == TaskSavePhase.saving && save.slow),
    );
    if (active.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final save in active)
              Material(
                color: save.phase == TaskSavePhase.failed
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        save.hasConflict
                            ? '${save.label}: The saved data changed. Reopen the latest task and review your retained edits. ${save.error}'
                            : save.phase == TaskSavePhase.failed
                            ? '${save.label}: Save failed. Your edits are kept for retry. ${save.error}'
                            : save.slow
                            ? '${save.label}: Still saving. Check your connection; not confirmed yet.'
                            : '${save.label}: Saving...',
                      ),
                      if (save.phase == TaskSavePhase.failed) ...[
                        if (save.canRetry)
                          TextButton(
                            onPressed: () => ref
                                .read(taskSavesProvider.notifier)
                                .retry(save.desired.id),
                            child: const Text('Retry save'),
                          ),
                        TextButton(
                          onPressed: _opening.contains(save.desired.id)
                              ? null
                              : () => _reopen(save),
                          child: Text(
                            _opening.contains(save.desired.id)
                                ? 'Opening latest data...'
                                : save.workflowKey == null
                                ? 'Reopen latest plan'
                                : 'Reopen latest task',
                          ),
                        ),
                        TextButton(
                          onPressed: () => showRetainedTaskEdits(context, save),
                          child: const Text('View retained edits'),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(taskSavesProvider.notifier)
                              .discard(save.desired.id),
                          child: const Text('Discard unsaved edits'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmLeavingUnsavedTasks(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(taskSavesProvider.notifier).hasUnsavedChanges) return true;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unsaved task changes'),
          content: const Text(
            'Some task changes are still saving or failed. Signing out loses retained unsaved edits. A write already in progress may still finish on the server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out anyway'),
            ),
          ],
        ),
      ) ??
      false;
}
