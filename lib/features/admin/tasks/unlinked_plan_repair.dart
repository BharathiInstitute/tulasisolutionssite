import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/tasks/task_save_controller.dart';

class UnlinkedPlanRepair extends ConsumerWidget {
  final Plan plan;

  const UnlinkedPlanRepair({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserProfileProvider).valueOrNull?.isAdmin != true ||
        plan.clientId == '__internal_practice__') {
      return const SizedBox.shrink();
    }
    final clients = ref.watch(taskClientsProvider);
    return clients.maybeWhen(
      data: (clients) {
        if (clients.any((client) => client.id == plan.clientId)) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No client linked'),
            ExpansionTile(
              title: const Text('Client link details'),
              children: [
                SelectableText(
                  'Saved client ID: ${plan.clientId.isEmpty ? '(missing)' : plan.clientId}',
                ),
              ],
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Link to client'),
              onPressed: () async {
                final linked = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _LinkPlanDialog(plan: plan, clients: clients),
                );
                if (linked == true && context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Plan linked. All task history was preserved.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _LinkPlanDialog extends ConsumerStatefulWidget {
  final Plan plan;
  final List<Client> clients;

  const _LinkPlanDialog({required this.plan, required this.clients});

  @override
  ConsumerState<_LinkPlanDialog> createState() => _LinkPlanDialogState();
}

class _LinkPlanDialogState extends ConsumerState<_LinkPlanDialog> {
  String? _selected;
  bool _saving = false;
  String? _error;

  Future<void> _link() async {
    final clientId = _selected;
    if (clientId == null) return;
    if (ref.read(currentUserProfileProvider).valueOrNull?.isAdmin != true) {
      setState(() => _error = 'Only admins can link an unlinked plan.');
      return;
    }
    final controller = ref.read(taskSavesProvider.notifier);
    final pending = ref.read(taskSavesProvider)[widget.plan.id];
    if (pending != null && pending.phase != TaskSavePhase.confirmed) {
      setState(
        () => _error = 'Finish or discard the pending save before linking.',
      );
      return;
    }
    final service = ref.read(firestoreServiceProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await service.relinkUnlinkedPlan(
        widget.plan.id,
        previousClientId: widget.plan.clientId,
        clientId: clientId,
        expectedTaskCount: widget.plan.features.toSet().length,
      );
      if (!mounted || !controller.mounted) return;
      controller.clearConfirmed(widget.plan.id);
      ref.invalidate(allPlansProvider);
      ref.invalidate(allPlansStreamProvider);
      ref.invalidate(taskClientsProvider);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not link plan: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Link the whole plan?'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan: ${widget.plan.name}'),
              Text(
                'This changes the client for all ${widget.plan.features.toSet().length} tasks in this plan, including every split unit, archived task, and completed task. Assignments, notes, drafts, dates, status, and pricing stay unchanged.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Link plan to'),
                items: [
                  const DropdownMenuItem(
                    value: '__internal_practice__',
                    child: Text('Practice (Internal)'),
                  ),
                  for (final client in widget.clients)
                    DropdownMenuItem(
                      value: client.id,
                      child: Text(client.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selected = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _selected == null ? null : _link,
          child: Text(_saving ? 'Linking...' : 'Confirm link'),
        ),
      ],
    ),
  );
}
