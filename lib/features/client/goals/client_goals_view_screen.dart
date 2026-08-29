import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class ClientGoalsViewScreen extends ConsumerWidget {
  const ClientGoalsViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(currentClientProvider);

    return AppShell(
      isAdmin: false,
      currentRoute: '/client/goals',
      title: 'My Goals',
      body: clientAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading client profile: $error'),
        data: (client) => client == null
            ? const Center(
                child: Text('Your client profile has not been linked yet.'),
              )
            : _buildGoalsForClient(context, ref, client.id),
      ),
    );
  }

  Widget _buildGoalsForClient(
    BuildContext context,
    WidgetRef ref,
    String clientId,
  ) {
    final goalsAsync = ref.watch(goalsProvider(clientId));
    final plansAsync = ref.watch(plansProvider(clientId));
    return goalsAsync.when(
      data: (goals) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPlanSection(context, plansAsync),
            const SizedBox(height: 16),
            if (goals.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    const Icon(Icons.flag_circle, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No goals assigned yet'),
                    const SizedBox(height: 16),
                    Text(
                      'Your account manager will set goals for you.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              ...goals.map((goal) => _buildGoalCard(context, goal)),
          ],
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading goals: $error'),
    );
  }

  Widget _buildPlanSection(
    BuildContext context,
    AsyncValue<List<Plan>> plansAsync,
  ) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final plan in plans) ...[
              PlanProgressCard(plan: plan),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading plan: $error'),
    );
  }

  Widget _buildGoalCard(BuildContext context, dynamic goal) {
    // Using dynamic here since Goal is imported, but we're showing the structure
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Leads',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: 50 leads',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Chip(
                  label: Text('Active'),
                  backgroundColor: Colors.orange,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Progress', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('45 / 50', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '90%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: 45 / 50,
                minHeight: 10,
                backgroundColor: Colors.grey.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This goal is linked to a guarantee. Missing the target may result in fee adjustments.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
