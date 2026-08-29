import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final clientAsync = ref.watch(currentClientProvider);

    return AppShell(
      isAdmin: false,
      currentRoute: '/client/dashboard',
      title: 'My Dashboard',
      actions: [
        IconButton(
          tooltip: 'Account details',
          icon: const Icon(Icons.manage_accounts),
          onPressed: () => context.push('/account-details'),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            ref.read(firebaseAuthServiceProvider).signOut();
          },
        ),
      ],
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }

          return clientAsync.when(
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) => CustomErrorWidget(
              message: 'Error loading client profile: $error',
            ),
            data: (client) {
              if (client == null) {
                return const Center(
                  child: Text('Your client profile has not been linked yet.'),
                );
              }
              final goalsAsync = ref.watch(goalsProvider(client.id));
              final softwareAsync = ref.watch(softwareStageProvider(client.id));
              final plansAsync = ref.watch(plansProvider(client.id));
              final contentLogsAsync = ref.watch(
                contentLogsProvider(client.id),
              );

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      Card(
                        color: Colors.green.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${user.email}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'View your goals, progress, and software setup status',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Stats
                      Text(
                        'Your Progress',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickStats(context, goalsAsync),
                      const SizedBox(height: 24),

                      // Active Plan
                      Text(
                        'Your Plan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _buildPlanStatus(context, plansAsync),
                      const SizedBox(height: 24),

                      // Active Goals Section
                      Text(
                        'Active Goals',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _buildActiveGoalsSection(context, goalsAsync),
                      const SizedBox(height: 24),

                      // Software Status
                      Text(
                        'Software Delivery Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _buildSoftwareStatus(context, softwareAsync),
                      const SizedBox(height: 24),

                      // Content Delivery
                      Text(
                        'This Month\'s Content',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _buildContentStatus(context, contentLogsAsync),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading dashboard: $error'),
      ),
    );
  }

  Widget _buildPlanStatus(
    BuildContext context,
    AsyncValue<List<Plan>> plansAsync,
  ) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No plan assigned yet.'),
            ),
          );
        }
        return Column(
          children: [
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

  Widget _buildQuickStats(BuildContext context, AsyncValue goalsAsync) {
    return goalsAsync.when(
      data: (goals) {
        final activeGoals = (goals as List)
            .where(
              (g) =>
                  g.stage.toString().contains('active') ||
                  g.stage.toString().contains('agreed'),
            )
            .length;
        final totalGoals = goals.length;
        final onTrack = totalGoals > 0
            ? ((goals).where((g) => g.progressPercentage >= 80).length /
                      totalGoals *
                      100)
                  .round()
            : 0;

        return Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.flag_circle,
                        size: 32,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Active Goals',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$activeGoals',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 32,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'On Track',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$onTrack%',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const LoadingWidget(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const LoadingWidget(),
              ),
            ),
          ),
        ],
      ),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading stats: $error'),
    );
  }

  Widget _buildActiveGoalsSection(BuildContext context, AsyncValue goalsAsync) {
    return goalsAsync.when(
      data: (goals) {
        final activeGoals = (goals as List)
            .where(
              (g) =>
                  g.stage.toString().contains('active') ||
                  g.stage.toString().contains('agreed'),
            )
            .toList();

        if (activeGoals.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No active goals',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(activeGoals.length, (index) {
                final goal = activeGoals[index];
                return Column(
                  children: [
                    _buildGoalProgressItem(
                      context,
                      title: goal.type.displayName,
                      current: goal.progressValue?.toInt() ?? 0,
                      target: goal.targetValue.toInt(),
                      progress: (goal.progressPercentage / 100)
                          .clamp(0, 1)
                          .toDouble(),
                    ),
                    if (index < activeGoals.length - 1) const Divider(),
                  ],
                );
              }),
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(padding: EdgeInsets.all(16), child: LoadingWidget()),
      ),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading goals: $error'),
    );
  }

  Widget _buildSoftwareStatus(BuildContext context, AsyncValue softwareAsync) {
    return softwareAsync.when(
      data: (software) {
        if (software == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No software setup information available',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Stage',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          software.stage.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (software.freePeriodEndDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Days Remaining',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${software.freePeriodDaysRemaining}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: software.freePeriodDaysRemaining > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Enabled Panels',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: software.panelsEnabled.map((panel) {
                    return Chip(
                      label: Text(panel),
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(padding: EdgeInsets.all(16), child: LoadingWidget()),
      ),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading software status: $error'),
    );
  }

  Widget _buildGoalProgressItem(
    BuildContext context, {
    required String title,
    required int current,
    required int target,
    required double progress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '$current / $target',
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
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.9 ? Colors.green : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentStatus(
    BuildContext context,
    AsyncValue contentLogsAsync,
  ) {
    return contentLogsAsync.when(
      data: (logs) {
        final now = DateTime.now();
        final monthLogs = (logs as List)
            .where((log) => log.month == now.month && log.year == now.year)
            .toList();

        if (monthLogs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No content delivered yet this month',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }

        final images = monthLogs.fold<int>(
          0,
          (sum, log) => sum + (log.imagesDelivered as int),
        );
        final reels = monthLogs.fold<int>(
          0,
          (sum, log) => sum + (log.reelsDelivered as int),
        );
        final revisions = monthLogs.fold<int>(
          0,
          (sum, log) => sum + (log.revisionRounds as int),
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _contentStat(context, 'Images', images, Colors.blue),
                _contentStat(context, 'Reels', reels, Colors.purple),
                _contentStat(context, 'Revisions', revisions, Colors.orange),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(padding: EdgeInsets.all(16), child: LoadingWidget()),
      ),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading content: $error'),
    );
  }

  Widget _contentStat(
    BuildContext context,
    String label,
    int value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
