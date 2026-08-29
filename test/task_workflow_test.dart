import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';

void main() {
  group('task workflow draft cycles', () {
    test('deduplicates repeated cycle numbers before the dropdown renders', () {
      const key = 'content#1';
      final plan = Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const ['Content: 2 reels'],
        startDate: DateTime(2024, 1, 1),
        taskWorkflow: {
          key: {
            'status': 'draft',
            'instructions': '',
            'update': '',
            'cycles': [
              {'cycle': 1, 'status': 'draft'},
              {'cycle': 2, 'status': 'draft'},
              {'cycle': 2, 'status': 'draft'},
            ],
          },
        },
      );

      final cycles = taskCycles(plan, key);
      final values = cycles
          .map((cycle) => (cycle['cycle'] as num?)?.toInt())
          .toList();

      expect(values, [1, 2]);
      expect(values.toSet().length, values.length);
    });

    test('new draft cycle numbers stay unique after saving', () {
      const key = 'content#1';
      final plan = Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const ['Content: 2 reels'],
        startDate: DateTime(2024, 1, 1),
        taskWorkflow: {
          key: {
            'status': 'draft',
            'instructions': '',
            'update': '',
            'cycles': [
              {'cycle': 1, 'status': 'draft'},
              {'cycle': 2, 'status': 'draft'},
              {'cycle': 2, 'status': 'draft'},
            ],
          },
        },
      );

      final updated = updateTaskWorkflow(
        plan,
        key,
        status: TaskStatus.draft,
        instructions: 'new draft',
        update: 'fresh update',
        cycleNumber: null,
      );

      final values = taskCycles(
        updated,
        key,
      ).map((cycle) => (cycle['cycle'] as num?)?.toInt()).toList();

      expect(values, [1, 2, 3]);
      expect(values.toSet().length, values.length);
    });

    test('current cycle advances to the next set after completion', () {
      const key = 'content#1';
      final plan = Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const ['Content: 2 reels'],
        startDate: DateTime(2024, 1, 1),
        taskWorkflow: {
          key: {
            'cycles': [
              {'cycle': 1, 'status': 'completed'},
              {'cycle': 2, 'status': 'draft'},
              {'cycle': 3, 'status': 'draft'},
            ],
          },
        },
      );

      expect(currentTaskCycle(plan, key)['cycle'], 2);
      expect(taskStatus(plan, key), TaskStatus.draft);
    });
  });
}
