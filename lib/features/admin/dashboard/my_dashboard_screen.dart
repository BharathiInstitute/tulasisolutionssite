import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class MyDashboardScreen extends ConsumerWidget {
  const MyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffIds = ref.watch(currentStaffIdsProvider);
    final plansAsync = ref.watch(allPlansStreamProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/my-dashboard',
      title: 'My Dashboard',
      actions: [
        IconButton(
          tooltip: 'Refresh my dashboard',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(allPlansStreamProvider),
        ),
      ],
      body: staffIds.isEmpty
          ? const Center(child: Text('No task information is available'))
          : plansAsync.when(
              loading: () => const LoadingWidget(),
              error: (error, stackTrace) => CustomErrorWidget(
                message: 'Could not load your dashboard: $error',
              ),
              data: (plans) =>
                  _MyDashboardContent(plans: plans, assigneeIds: staffIds),
            ),
    );
  }
}

class _MyDashboardContent extends StatelessWidget {
  final List<Plan> plans;
  final List<String> assigneeIds;

  const _MyDashboardContent({required this.plans, required this.assigneeIds});

  @override
  Widget build(BuildContext context) {
    final assigned = <({Plan plan, String key})>[];
    for (final plan in plans) {
      for (final entry in plan.taskWorkflow.entries) {
        if (assigneeIds.contains(taskAssigneeId(plan, entry.key))) {
          assigned.add((plan: plan, key: entry.key));
        }
      }
    }
    final completed = assigned
        .where(
          (task) => taskStatus(task.plan, task.key) == TaskStatus.completed,
        )
        .length;
    final active = assigned.length - completed;
    final progress = assigned.isEmpty ? 0.0 : completed / assigned.length;
    final byCategory = <String, int>{};
    for (final task in assigned) {
      final rawFeature = task.key.split('#').first;
      final category = parseFeature(rawFeature).category;
      byCategory[category] = (byCategory[category] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('My workload', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Tasks assigned to your account across all client plans.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _PersonalMetric(
              label: 'Assigned tasks',
              value: '${assigned.length}',
              icon: Icons.assignment_ind_outlined,
              color: Colors.green,
            ),
            _PersonalMetric(
              label: 'In progress',
              value: '$active',
              icon: Icons.pending_actions_outlined,
              color: Colors.orange,
            ),
            _PersonalMetric(
              label: 'Completed',
              value: '$completed',
              icon: Icons.task_alt_outlined,
              color: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My progress',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress, minHeight: 10),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).round()}% complete - $completed of ${assigned.length} tasks',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.go('/admin/my-tasks'),
                  icon: const Icon(Icons.assignment_ind_outlined),
                  label: const Text('View my tasks'),
                ),
              ],
            ),
          ),
        ),
        if (byCategory.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            'Work by category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                children: byCategory.entries
                    .map(
                      (entry) => SizedBox(
                        width: 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.value}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PersonalMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PersonalMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 14),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
