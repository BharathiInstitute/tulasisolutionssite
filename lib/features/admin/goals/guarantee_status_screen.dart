import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class GuaranteeStatusScreen extends ConsumerStatefulWidget {
  final String clientId;

  const GuaranteeStatusScreen({super.key, required this.clientId});

  @override
  ConsumerState<GuaranteeStatusScreen> createState() =>
      _GuaranteeStatusScreenState();
}

class _GuaranteeStatusScreenState extends ConsumerState<GuaranteeStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider(widget.clientId));

    return goalsAsync.when(
      data: (goals) {
        // Filter goals linked to guarantee
        final guaranteeGoals = goals.where((g) => g.guaranteeLinked).toList();

        // Count waivers
        final waivers = guaranteeGoals.where(
          (g) => g.stage == GoalStage.missedGuaranteeApplied,
        );
        final waiverCount = waivers.length;
        final totalGuaranteedGoals = guaranteeGoals.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guarantee Status',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // Overview Cards
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
                              totalGuaranteedGoals.toString(),
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

              // Guarantee Status Explanation
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
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Guarantee Active',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'When a guaranteed goal is missed, the next month\'s subscription fee is waived automatically. This applies to goals with the "Link to Guarantee" checkbox enabled.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Guaranteed Goals List
              if (guaranteeGoals.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.shield, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No guaranteed goals yet'),
                      const SizedBox(height: 16),
                      const Text(
                        'When you create goals with the "Link to Guarantee" checkbox, they will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  'Guaranteed Goals',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...guaranteeGoals.map(
                  (goal) => _buildGuaranteeGoalCard(context, goal, waivers),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading guarantee status: $error'),
    );
  }

  Widget _buildGuaranteeGoalCard(
    BuildContext context,
    Goal goal,
    Iterable<Goal> waivers,
  ) {
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
                  )
                else
                  Chip(
                    label: Text(goal.stage.displayName),
                    backgroundColor: Colors.blue.withValues(alpha: 0.2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (goal.progressValue != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress: ${goal.progressValue?.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)} (${goal.progressPercentage.toStringAsFixed(0)}%)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (goal.progressPercentage / 100).clamp(0, 1),
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
              ),
            if (isMissed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fee Waived',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next month\'s subscription fee has been waived due to missed guarantee.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
