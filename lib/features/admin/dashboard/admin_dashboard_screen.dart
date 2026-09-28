import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/theme/app_theme.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsListProvider);
    final plansAsync = ref.watch(allPlansStreamProvider);
    final paymentsAsync = ref.watch(paymentsProvider);
    final currentUser = ref.watch(firebaseAuthServiceProvider).getCurrentUser();
    final clients = clientsAsync.valueOrNull ?? const <Client>[];
    final plans = plansAsync.valueOrNull ?? const <Plan>[];
    final payments = paymentsAsync.valueOrNull ?? const <PaymentRecord>[];

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/dashboard',
      title: 'Dashboard',
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(clientsListProvider);
            ref.invalidate(allPlansStreamProvider);
            ref.invalidate(paymentsProvider);
          },
        ),
      ],
      body: _DashboardContent(
        clients: clients,
        plans: plans,
        payments: payments,
        assigneeId: currentUser?.uid,
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final List<Client> clients;
  final List<Plan> plans;
  final List<PaymentRecord> payments;
  final String? assigneeId;

  const _DashboardContent({
    required this.clients,
    required this.plans,
    required this.payments,
    required this.assigneeId,
  });

  @override
  Widget build(BuildContext context) {
    final activeClients = clients
        .where((client) => client.stage == ClientStage.client)
        .length;
    final openPlans = plans.where((plan) => !plan.isCompleted).length;
    final pendingPayments = payments
        .where((payment) => payment.status == PaymentStatus.pending)
        .toList();
    final pendingAmount = pendingPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    final stageCounts = {
      for (final stage in ClientStage.values)
        stage: clients.where((client) => client.stage == stage).length,
    };
    final assignedTasks = <({Plan plan, String key})>[];
    if (assigneeId != null) {
      for (final plan in plans) {
        for (final entry in plan.taskWorkflow.entries) {
          if (taskAssigneeId(plan, entry.key) == assigneeId) {
            assignedTasks.add((plan: plan, key: entry.key));
          }
        }
      }
    }
    final completedAssignedTasks = assignedTasks
        .where(
          (task) => taskStatus(task.plan, task.key) == TaskStatus.completed,
        )
        .length;
    final personalProgress = assignedTasks.isEmpty
        ? 0
        : (completedAssignedTasks / assignedTasks.length * 100).round();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Operations overview',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'A live view of leads, delivery work, and payments.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 48) / 4
                : constraints.maxWidth >= 560
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricTile(
                  width: tileWidth,
                  label: 'Total leads',
                  value: '${clients.length}',
                  icon: Icons.people_outline,
                  color: AppTheme.deepGreen,
                  onTap: () => context.go('/admin/leads'),
                ),
                _MetricTile(
                  width: tileWidth,
                  label: 'Active clients',
                  value: '$activeClients',
                  icon: Icons.handshake_outlined,
                  color: Colors.teal,
                  onTap: () => context.go('/admin/consultations'),
                ),
                _MetricTile(
                  width: tileWidth,
                  label: 'Open plan work',
                  value: '$openPlans',
                  icon: Icons.task_alt_outlined,
                  color: Colors.indigo,
                  onTap: () => context.go('/admin/tasks'),
                ),
                _MetricTile(
                  width: tileWidth,
                  label: 'Pending payments',
                  value: 'Rs. ${pendingAmount.toStringAsFixed(0)}',
                  detail: '${pendingPayments.length} to review',
                  icon: Icons.payments_outlined,
                  color: Colors.orange.shade800,
                  onTap: () => context.go('/admin/payments'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text('My work', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricTile(
              width: 220,
              label: 'Assigned to me',
              value: '${assignedTasks.length}',
              detail: '$completedAssignedTasks completed',
              icon: Icons.assignment_ind_outlined,
              color: AppTheme.deepGreen,
              onTap: () => context.go('/admin/my-tasks'),
            ),
            _MetricTile(
              width: 220,
              label: 'My task progress',
              value: '$personalProgress%',
              detail: assignedTasks.isEmpty
                  ? 'No tasks assigned'
                  : '$completedAssignedTasks of ${assignedTasks.length} complete',
              icon: Icons.trending_up_outlined,
              color: Colors.teal,
              onTap: () => context.go('/admin/my-tasks'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Lead pipeline', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 18,
              children: ClientStage.values
                  .where((stage) => stageCounts[stage]! > 0)
                  .map(
                    (stage) => _StageCount(
                      label: stage.displayName,
                      count: stageCounts[stage]!,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Quick access', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickLink(
              label: 'Manage leads',
              icon: Icons.people_outline,
              route: '/admin/leads',
            ),
            _QuickLink(
              label: 'Review payments',
              icon: Icons.payments_outlined,
              route: '/admin/payments',
            ),
            _QuickLink(
              label: 'Open tasks',
              icon: Icons.task_alt_outlined,
              route: '/admin/tasks',
            ),
            _QuickLink(
              label: 'My tasks',
              icon: Icons.assignment_ind_outlined,
              route: '/admin/my-tasks',
            ),
            _QuickLink(
              label: 'View progress',
              icon: Icons.trending_up_outlined,
              route: '/admin/tasks',
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricTile({
    required this.width,
    required this.label,
    required this.value,
    this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 16),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(detail!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageCount extends StatelessWidget {
  final String label;
  final int count;

  const _StageCount({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;

  const _QuickLink({
    required this.label,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go(route),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
