import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';

void main() {
  group('task workflow draft cycles', () {
    test('renaming a task preserves metadata and workflow keys', () {
      const oldFeature = 'Content: 2 reels';
      final plan = Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const [oldFeature],
        tasks: const [
          ClientTask(
            id: 'task-1',
            category: 'Content',
            title: '2 reels',
            instructions: 'Keep this brief',
            order: 0,
            source: ClientTaskSource.customIncluded,
            addedReason: 'Campaign',
          ),
        ],
        completedFeatures: const [oldFeature],
        featureProgress: const {oldFeature: 50},
        taskWorkflow: const {
          '$oldFeature#1': {'assignedTo': 'staff-1'},
          '$oldFeature#2': {'priority': 'high'},
        },
        startDate: DateTime(2024, 1, 1),
      );

      final updated = renamePlanTask(
        plan,
        oldFeature,
        category: 'Content / Video Kit',
        title: '2 campaign reels',
      );
      const newFeature = 'Content / Video Kit: 2 campaign reels';

      expect(updated.features, const [newFeature]);
      expect(updated.completedFeatures, const [newFeature]);
      expect(updated.featureProgress, const {newFeature: 50});
      expect(updated.taskWorkflow.keys, const {
        '$newFeature#1',
        '$newFeature#2',
      });
      expect(updated.tasks.single.feature, newFeature);
      expect(updated.tasks.single.instructions, 'Keep this brief');
      expect(updated.tasks.single.addedReason, 'Campaign');
    });

    test('archiving a task preserves its workflow details', () {
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
            'assignedTo': 'staff-1',
            'priority': 'high',
            'status': 'started',
          },
        },
      );

      final archived = setTaskArchived(plan, key, true);

      expect(taskIsArchived(archived, key), isTrue);
      expect(taskAssigneeId(archived, key), 'staff-1');
      expect(taskPriority(archived, key), 'high');
      expect(taskStatus(archived, key), TaskStatus.started);
    });

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
        status: TaskStatus.notAssigned,
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

    test('latest draft cycle determines the task stage', () {
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

      expect(currentTaskCycle(plan, key)['cycle'], 3);
      expect(taskStatus(plan, key), TaskStatus.notAssigned);
    });

    test('draft saves preserve task assignment and priority', () {
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
            'assignedTo': 'staff-1',
            'assignedToName': 'Asha',
            'priority': 'high',
            'cycles': [
              {'cycle': 1, 'status': 'draft'},
            ],
          },
        },
      );

      final updated = replaceTaskWorkflowCycles(plan, key, [
        {'cycle': 1, 'status': 'started', 'instructions': 'Updated'},
      ]);

      expect(taskAssigneeId(updated, key), 'staff-1');
      expect(taskAssigneeName(updated, key), 'Asha');
      expect(taskPriority(updated, key), 'high');
      expect(taskStatus(updated, key), TaskStatus.started);
    });

    test('assignment and legacy stages map to the ordered workflow', () {
      const key = 'content#1';
      Plan planWith(String? assignedTo, String status) => Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const ['Content: 2 reels'],
        startDate: DateTime(2024, 1, 1),
        taskWorkflow: {
          key: {
            'assignedTo': assignedTo,
            'cycles': [
              {'cycle': 1, 'status': status},
            ],
          },
        },
      );

      expect(taskStatus(planWith(null, 'draft'), key), TaskStatus.notAssigned);
      expect(
        taskStatus(planWith('staff-1', 'draft'), key),
        TaskStatus.draftCycle,
      );
      expect(
        taskStatus(planWith('staff-1', 'inProgress'), key),
        TaskStatus.draftCycle,
      );
      expect(
        taskStatus(planWith('staff-1', 'awaitingConfirmation'), key),
        TaskStatus.draftCycle,
      );
      expect(
        taskStatus(planWith('staff-1', 'completed'), key),
        TaskStatus.completed,
      );
    });

    test('legacy draft statuses map to draft-cycle substages', () {
      const key = 'content#1';
      Plan planWith(String status) => Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const ['Content: 2 reels'],
        startDate: DateTime(2024, 1, 1),
        taskWorkflow: {
          key: {
            'assignedTo': 'staff-1',
            'cycles': [
              {'cycle': 1, 'status': status},
            ],
          },
        },
      );

      expect(
        draftCycleStage(planWith('draft'), key),
        DraftCycleStage.instructions,
      );
      expect(
        draftCycleStage(planWith('inProgress'), key),
        DraftCycleStage.working,
      );
      expect(
        draftCycleStage(planWith('awaitingConfirmation'), key),
        DraftCycleStage.confirmation,
      );
    });

    test('client rejection creates the next draft at instructions', () {
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
            'assignedTo': 'staff-1',
            'assignedToName': 'Asha',
            'priority': 'high',
            'cycles': [
              {
                'cycle': 1,
                'status': 'draftCycle',
                'draftStage': 'confirmation',
              },
            ],
          },
        },
      );

      final updated = createNextDraftCycle(plan, key);

      expect(taskCycles(updated, key).length, 2);
      expect(currentTaskCycle(updated, key)['cycle'], 2);
      expect(draftCycleStage(updated, key), DraftCycleStage.instructions);
      expect(taskStatus(updated, key), TaskStatus.draftCycle);
      expect(taskAssigneeName(updated, key), 'Asha');
      expect(taskPriority(updated, key), 'high');
    });

    test('client satisfaction completes the confirmed draft', () {
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
            'assignedTo': 'staff-1',
            'cycles': [
              {
                'cycle': 1,
                'status': 'draftCycle',
                'draftStage': 'confirmation',
                'instructions': 'Review this version',
              },
            ],
          },
        },
      );

      final updated = updateTaskWorkflow(
        plan,
        key,
        status: TaskStatus.completed,
        instructions: 'Review this version',
        update: '',
        clientConfirmed: true,
        cycleNumber: 1,
      );

      expect(taskStatus(updated, key), TaskStatus.completed);
      expect(currentTaskCycle(updated, key)['clientConfirmed'], isTrue);
      expect(taskCycles(updated, key).length, 1);
    });

    test('timer starts, stops, and resumes without counting paused time', () {
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
            'assignedTo': 'staff-1',
            'cycles': [
              {'cycle': 1, 'status': 'assigned'},
            ],
          },
        },
      );

      final started = setTaskTimerRunning(
        plan,
        key,
        true,
        now: DateTime(2026, 9, 16, 9),
      );
      expect(taskTimerIsRunning(started, key), isTrue);
      expect(
        taskElapsedTime(started, key, now: DateTime(2026, 9, 16, 9, 30)),
        const Duration(minutes: 30),
      );

      final stopped = setTaskTimerRunning(
        started,
        key,
        false,
        now: DateTime(2026, 9, 16, 9, 30),
      );
      expect(taskTimerIsRunning(stopped, key), isFalse);
      expect(taskElapsedTime(stopped, key), const Duration(minutes: 30));

      final resumed = setTaskTimerRunning(
        stopped,
        key,
        true,
        now: DateTime(2026, 9, 16, 10),
      );
      expect(
        taskElapsedTime(resumed, key, now: DateTime(2026, 9, 16, 10, 15)),
        const Duration(minutes: 45),
      );
    });

    test('status can be completed without creating a draft', () {
      const key = 'setup';
      final plan = Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const ['Software: setup'],
        startDate: DateTime(2024, 1, 1),
        taskWorkflow: {
          key: {'assignedTo': 'staff-1', 'status': 'assigned'},
        },
      );

      final completed = setTaskStatus(plan, key, TaskStatus.completed);

      expect(taskStatus(completed, key), TaskStatus.completed);
      expect(taskCycles(completed, key), hasLength(1));
      expect(completed.taskWorkflow[key]?['cycles'], isNull);
    });

    test('updating a work link preserves the draft workflow', () {
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
            'assignedTo': 'staff-1',
            'cycles': [
              {'cycle': 1, 'status': 'draftCycle', 'instructions': 'Review'},
            ],
          },
        },
      );

      final updated = updateTaskCycleWorkLink(
        plan,
        key,
        1,
        'https://example.com/work',
      );

      expect(
        currentTaskCycle(updated, key)['draftLink'],
        'https://example.com/work',
      );
      expect(currentTaskCycle(updated, key)['instructions'], 'Review');
    });

    test('client instructions update one draft without losing history', () {
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
            'assignedTo': 'staff-1',
            'priority': 'urgent',
            'cycles': [
              {
                'cycle': 1,
                'status': 'draftCycle',
                'draftStage': 'confirmation',
                'instructions': 'First request',
              },
              {
                'cycle': 2,
                'status': 'draftCycle',
                'draftStage': 'instructions',
                'instructions': '',
              },
            ],
          },
        },
      );

      final updated = updateTaskCycleInstructions(
        plan,
        key,
        2,
        '  Revised client instruction  ',
      );

      final cycles = taskCycles(updated, key);
      expect(cycles.length, 2);
      expect(cycles.first['instructions'], 'First request');
      expect(cycles.last['instructions'], 'Revised client instruction');
      expect(taskAssigneeId(updated, key), 'staff-1');
      expect(taskPriority(updated, key), 'urgent');
    });

    test(
      'delivery task due date and internal notes do not alter its draft history',
      () {
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
                {
                  'cycle': 1,
                  'status': 'assigned',
                  'instructions': 'Use the brief',
                },
              ],
            },
          },
        );

        final dueAt = DateTime(2024, 2, 1);
        final updated = updateTaskManagementDetails(
          plan,
          key,
          dueAt: dueAt,
          internalNotes: 'Designer needs the client photos first.',
        );

        expect(taskDueAt(updated, key), dueAt);
        expect(
          taskInternalNotes(updated, key),
          'Designer needs the client photos first.',
        );
        expect(
          taskCycles(updated, key).single['instructions'],
          'Use the brief',
        );
      },
    );
  });
}
