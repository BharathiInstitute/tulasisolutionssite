import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/feature_progress_widgets.dart';
import '../../../core/tasks/task_save_controller.dart';

Future<bool> confirmTaskDeletion(
  BuildContext context,
  WidgetRef ref, {
  required String planId,
  required String feature,
}) async {
  if (ref.read(currentUserProfileProvider).valueOrNull?.isAdmin != true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Only admins can delete tasks.')),
    );
    return false;
  }
  final pending = ref.read(taskSavesProvider)[planId];
  if (pending != null && pending.phase != TaskSavePhase.confirmed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finish or discard the pending save before deleting.'),
      ),
    );
    return false;
  }
  final confirmation = TextEditingController();
  var deleting = false;
  String? error;
  final route = DialogRoute<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => PopScope(
        canPop: !deleting,
        child: AlertDialog(
          title: const Text('Delete task?'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(parseFeature(feature).text),
                  const SizedBox(height: 12),
                  const Text(
                    'This permanently deletes this task, all its units, drafts, '
                    'and progress. Other tasks and the plan are kept. '
                    'This cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmation,
                    autofocus: true,
                    enabled: !deleting,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Type DELETE to confirm',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: deleting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: confirmation,
              builder: (context, value, child) => FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: deleting || value.text != 'DELETE'
                    ? null
                    : () async {
                        if (ref
                                .read(currentUserProfileProvider)
                                .valueOrNull
                                ?.isAdmin !=
                            true) {
                          setDialogState(
                            () => error = 'Only admins can delete tasks.',
                          );
                          return;
                        }
                        setDialogState(() {
                          deleting = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(firestoreServiceProvider)
                              .deletePlanTask(planId, feature, value.text);
                          ref.invalidate(allPlansProvider);
                          ref
                              .read(taskSavesProvider.notifier)
                              .clearConfirmed(planId);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (failure) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              deleting = false;
                              error = 'Could not delete task: $failure';
                            });
                          }
                        }
                      },
                child: Text(deleting ? 'Deleting...' : 'Delete'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  try {
    final deleted = await Navigator.of(context).push(route) ?? false;
    await route.completed;
    if (deleted && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task deleted.')));
    }
    return deleted;
  } finally {
    confirmation.dispose();
  }
}
