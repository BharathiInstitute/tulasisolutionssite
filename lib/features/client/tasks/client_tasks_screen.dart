import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          if (client == null) {
            return const Center(child: Text('Client profile not found'));
          }
          final plansAsync = ref.watch(plansProvider(client.id));
          return plansAsync.when(
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) =>
                CustomErrorWidget(message: 'Error loading tasks: $error'),
            data: (plans) => _ClientTaskList(plans: plans),
          );
        },
      ),
    );
  }
}

class _ClientTaskList extends StatelessWidget {
  final List<Plan> plans;

  const _ClientTaskList({required this.plans});

  @override
  Widget build(BuildContext context) {
    final rows = <_ClientTaskItem>[];
    for (final plan in plans) {
      for (final raw in plan.features) {
        final text = parseFeature(raw).text;
        final match = RegExp(
          r'^(\d+)\s+(reels?|designs?|videos?)',
          caseSensitive: false,
        ).firstMatch(text);
        final total = int.tryParse(match?.group(1) ?? '');
        if (total != null && total > 0) {
          for (var i = 1; i <= total; i++) {
            rows.add(
              _ClientTaskItem(
                plan: plan,
                rawFeature: raw,
                unitIndex: i,
                unitTotal: total,
              ),
            );
          }
        } else {
          rows.add(_ClientTaskItem(plan: plan, rawFeature: raw));
        }
      }
    }

    if (rows.isEmpty) return const Center(child: Text('No tasks assigned yet'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _ClientTaskRow(item: rows[index]),
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
  Map<String, dynamic>? get workflow => plan.taskWorkflow[key];
  TaskStatus get status => taskStatus(plan, key);
  bool get completed => status == TaskStatus.completed;
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

  const _ClientTaskRow({required this.item});

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructions = taskText(item.plan, item.key, 'instructions');
    final update = taskText(item.plan, item.key, 'update');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Icon(
          item.completed ? Icons.verified : Icons.assignment_outlined,
          color: item.completed ? Colors.green : Colors.orange,
        ),
        title: Text(item.text),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${parseFeature(item.rawFeature).category} • ${item.status.label}',
            ),
            if (instructions.isNotEmpty) Text('Instructions: $instructions'),
            if (update.isNotEmpty) Text('Update: $update'),
          ],
        ),
        trailing: item.completed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(
                onPressed: () => _confirm(context, ref),
                child: const Text('Confirm'),
              ),
      ),
    );
  }
}

extension on TaskStatus {
  String get label => switch (this) {
    TaskStatus.draft => 'Draft',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.awaitingConfirmation => 'Awaiting Client Confirmation',
    TaskStatus.completed => 'Completed',
  };
}
