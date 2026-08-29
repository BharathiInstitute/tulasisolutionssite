import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'add_edit_goal_screen.dart';

class GoalsManagementScreen extends ConsumerWidget {
  final String clientId;

  const GoalsManagementScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider(clientId));
    final clientAsync = ref.watch(clientProvider(clientId));
    final clientName = clientAsync.valueOrNull?.name ?? 'Client';
    final guaranteeGoals = goalsAsync.whenData(
      (goals) => goals.where((g) => g.guaranteeLinked).toList(),
    );

    return DefaultTabController(
      length: 2,
      child: AppShell(
        isAdmin: true,
        currentRoute: '/admin/leads',
        title: clientName,
        bottom: const TabBar(
          tabs: [
            Tab(text: 'All Goals'),
            Tab(text: 'Guarantee Status'),
          ],
        ),
        body: TabBarView(
          children: [
            // All Goals Tab
            goalsAsync.when(
              data: (goals) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => DraggableScrollableSheet(
                                expand: false,
                                builder: (context, scrollController) =>
                                    AddEditGoalScreen(clientId: clientId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Goal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ),
                    if (goals.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.flag_circle,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text('No goals created yet'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) =>
                                        DraggableScrollableSheet(
                                          expand: false,
                                          builder:
                                              (context, scrollController) =>
                                                  AddEditGoalScreen(
                                                    clientId: clientId,
                                                  ),
                                        ),
                                  );
                                },
                                child: const Text('Create First Goal'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: goals.length,
                          itemBuilder: (context, index) {
                            final goal = goals[index];
                            return GoalListCard(
                              goal: goal,
                              onEdit: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) =>
                                      DraggableScrollableSheet(
                                        expand: false,
                                        builder: (context, scrollController) =>
                                            AddEditGoalScreen(
                                              clientId: clientId,
                                              existingGoal: goal,
                                            ),
                                      ),
                                );
                              },
                              onDelete: () async {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Goal?'),
                                    content: const Text(
                                      'Are you sure you want to delete this goal? This action cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(firestoreServiceProvider)
                                                .deleteGoal(clientId, goal.id);
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Goal deleted successfully',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, stackTrace) =>
                  CustomErrorWidget(message: 'Error loading goals: $error'),
            ),
            // Guarantee Status Tab
            _buildGuaranteeStatusTab(context, ref, guaranteeGoals),
          ],
        ),
      ),
    );
  }

  Widget _buildGuaranteeStatusTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Goal>> guaranteeGoals,
  ) {
    return guaranteeGoals.when(
      data: (goals) {
        final waiverCount = goals
            .where((g) => g.stage == GoalStage.missedGuaranteeApplied)
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Guaranteed Goals',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              goals.length.toString(),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: Colors.blue),
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
                            Text(
                              'Fee Waivers Used',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              waiverCount.toString(),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: waiverCount > 0
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shield,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Guarantee Active',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'When a guaranteed goal is missed, the next month\'s subscription fee is waived automatically.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (goals.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guaranteed Goals',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...goals.map(
                      (goal) => _buildGuaranteeGoalCard(context, goal),
                    ),
                  ],
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const Icon(Icons.shield, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No guaranteed goals yet',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading guarantee status: $error'),
    );
  }

  Widget _buildGuaranteeGoalCard(BuildContext context, Goal goal) {
    final isMissed = goal.stage == GoalStage.missedGuaranteeApplied;
    final isAchieved = goal.stage == GoalStage.achieved;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isMissed
          ? Colors.orange.withValues(alpha: 0.05)
          : isAchieved
          ? Colors.green.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.05),
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
                        '${goal.type.displayName} - ${goal.period}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${goal.targetValue.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isMissed)
                  const Chip(
                    label: Text('Fee Waived'),
                    backgroundColor: Colors.orange,
                    labelStyle: TextStyle(color: Colors.white),
                  )
                else if (isAchieved)
                  const Chip(
                    label: Text('Achieved'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            if (goal.progressValue != null) ...[
              const SizedBox(height: 16),
              Text(
                'Progress: ${goal.progressValue?.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (goal.progressPercentage / 100).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMissed
                        ? Colors.orange
                        : isAchieved
                        ? Colors.green
                        : Colors.blue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GoalListCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GoalListCard({
    super.key,
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getStageColor(GoalStage stage) {
    switch (stage) {
      case GoalStage.draft:
        return Colors.grey;
      case GoalStage.agreed:
        return Colors.blue;
      case GoalStage.active:
        return Colors.orange;
      case GoalStage.underReview:
        return Colors.purple;
      case GoalStage.achieved:
        return Colors.green;
      case GoalStage.missedGuaranteeApplied:
        return Colors.red;
      case GoalStage.archived:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                        '${goal.type.displayName} - ${goal.period}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${goal.targetValue.toStringAsFixed(1)} (Baseline: ${goal.baselineValue.toStringAsFixed(1)} + ${(goal.liftPercentage * 100).toStringAsFixed(0)}%)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(onTap: onEdit, child: const Text('Edit')),
                    PopupMenuItem(onTap: onDelete, child: const Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StageChip(
                  label: goal.stage.displayName,
                  backgroundColor: _getStageColor(
                    goal.stage,
                  ).withValues(alpha: 0.2),
                  textColor: _getStageColor(goal.stage),
                ),
                if (goal.guaranteeLinked)
                  const Chip(
                    label: Text('Guarantee'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            if (goal.progressValue != null) ...[
              const SizedBox(height: 12),
              Text(
                'Progress: ${goal.progressValue?.toStringAsFixed(1)} of ${goal.targetValue.toStringAsFixed(1)} (${goal.progressPercentage.toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (goal.progressPercentage / 100).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.progressPercentage >= 100
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
