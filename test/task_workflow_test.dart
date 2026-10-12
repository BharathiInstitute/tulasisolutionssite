import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';

void main() {
  test('task due filters use local calendar days and individual workflow keys', () {
    final now = DateTime(2026, 10, 10, 14);
    final plan = Plan(
      id: 'due-filters',
      clientId: 'client',
      type: PlanType.setup,
      name: 'Tasks',
      price: 0,
      startDate: now,
      features: const ['Content: Artwork'],
      taskWorkflow: {
        'overdue': {'dueAt': DateTime(2026, 10, 9).toIso8601String()},
        'today': {'dueAt': DateTime(2026, 10, 10, 23, 59).toIso8601String()},
        'tomorrow': {'dueAt': DateTime(2026, 10, 11).toUtc().toIso8601String()},
        'Content: Artwork::unit:1': {
          'dueAt': DateTime(2026, 10, 10, 18).toIso8601String(),
        },
      },
    );
    for (final entry in {
      'overdue': TaskDueFilter.todayAndOverdue,
      'today': TaskDueFilter.todayAndOverdue,
      'tomorrow': TaskDueFilter.upcoming,
      'unscheduled': TaskDueFilter.unscheduled,
      'Content: Artwork::unit:1': TaskDueFilter.todayAndOverdue,
    }.entries) {
      for (final filter in TaskDueFilter.values) {
        expect(
          matchesTaskDueFilter(plan, entry.key, filter, now),
          filter == entry.value,
          reason: '${entry.key}: $filter',
        );
      }
    }
  });

  test(
    'Sales task queues count each real task independently of customer reminders',
    () {
      final now = DateTime(2026, 10, 10, 14);
      final plan = Plan(
        id: 'sales',
        clientId: 'same-customer',
        type: PlanType.setup,
        name: 'Sales Tasks',
        price: 0,
        startDate: now,
        features: const [
          'Sales / Call: Overdue',
          'Sales / Meeting: Today',
          'Sales / Call: Future',
          'Sales / Call: Unscheduled',
          'Sales / Call: Completed',
          'Sales / Call: Archived',
          'Content: Delivery',
          'Sales / Call: Overdue',
        ],
        completedFeatures: const ['Sales / Call: Completed'],
        taskWorkflow: {
          'Sales / Call: Overdue': {'dueAt': '2026-10-09T12:00:00'},
          'Sales / Meeting: Today': {'dueAt': '2026-10-10T18:00:00'},
          'Sales / Call: Future': {'dueAt': '2026-10-11T00:00:00'},
          'Sales / Call: Archived': {'isArchived': true},
        },
      );
      final tasks = salesTasks([plan])..sort(compareSalesTaskDue);
      expect(tasks, hasLength(6));
      expect(tasks.first.feature, 'Sales / Call: Overdue');
      for (final entry in {
        SalesTaskQueue.todayAndOverdue: 2,
        SalesTaskQueue.upcoming: 1,
        SalesTaskQueue.unscheduled: 1,
        SalesTaskQueue.active: 4,
        SalesTaskQueue.completed: 1,
      }.entries) {
        expect(
          tasks.where((task) => matchesSalesTaskQueue(task, entry.key, now)),
          hasLength(entry.value),
        );
      }
      expect(salesTasks(const []), isEmpty);
    },
  );

  test(
    'sales record contact edits preserve concurrent additions and reject conflicting edits',
    () {
      final original = <String, dynamic>{
        'id': 'old',
        'method': 'Call',
        'outcome': 'Interested',
        'notes': 'Original',
      };
      final concurrent = <String, dynamic>{
        'id': 'concurrent',
        'notes': 'New contact',
      };
      final edited = {...original, 'notes': 'Corrected'};
      final merged = mergeSalesRecordContacts(
        [original, concurrent],
        [original],
        [edited],
      );
      expect(merged.first['notes'], 'Corrected');
      expect(merged.last, concurrent);
      expect(mergeSalesRecordContacts([original, concurrent], [original], []), [
        concurrent,
      ]);
      expect(
        () => mergeSalesRecordContacts(
          [
            {...original, 'notes': 'Someone else edited'},
          ],
          [original],
          [edited],
        ),
        throwsStateError,
      );
    },
  );

  test(
    'sales queue excludes completed and archived tasks and sorts next actions',
    () {
      final plan = Plan(
        id: 'sales',
        clientId: 'lead',
        type: PlanType.setup,
        name: 'Sales Tasks',
        price: 0,
        startDate: DateTime(2026, 10, 2),
        features: const [
          'Sales / Call: Later',
          'Sales / Proposal: First',
          'Sales / Call: Done',
          'Sales / Call: Archived',
          'Content: Delivery',
        ],
        completedFeatures: const ['Sales / Call: Done'],
        taskWorkflow: {
          'Sales / Call: Later': {
            'dueAt': '2026-10-04T15:00:00',
            'assignedTo': 'staff',
          },
          'Sales / Proposal: First': {
            'dueAt': '2026-10-02T15:00:00',
            'assignedTo': 'staff',
          },
          'Sales / Call: Archived': {'isArchived': true},
        },
      );
      final tasks = openSalesTasksByClient([plan])['lead']!;
      expect(tasks.map((task) => task.feature), [
        'Sales / Proposal: First',
        'Sales / Call: Later',
      ]);
      final client = Client(
        id: 'lead',
        name: 'Lead',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        createdDate: DateTime(2026, 10, 1),
      );
      final now = DateTime(2026, 10, 2, 16);
      final legacyClient = client.copyWith(
        notes: 'Customer context',
        followUpNotes: 'Call tomorrow',
      );
      expect(
        salesRecordNotes(legacyClient, tasks.first),
        'Customer context\n\nCall tomorrow',
      );
      final recorded = tasks.first.plan.copyWith(
        taskWorkflow: {
          tasks.first.feature: {
            'internalNotes': 'Edited merged notes',
            'salesRecordMerged': true,
          },
        },
      );
      expect(
        salesRecordNotes(legacyClient, (
          plan: recorded,
          feature: tasks.first.feature,
        )),
        'Edited merged notes',
      );
      expect(matchesSalesQueue(client, tasks, SalesQueue.today, now), isTrue);
      expect(
        matchesSalesQueue(
          client.copyWith(followUpAt: now.add(const Duration(days: 1))),
          [],
          SalesQueue.today,
          now,
        ),
        isFalse,
      );
      expect(
        matchesSalesQueue(
          client.copyWith(followUpAt: now.subtract(const Duration(days: 2))),
          [],
          SalesQueue.overdue,
          now,
        ),
        isTrue,
      );
      expect(matchesSalesQueue(client, tasks, SalesQueue.today, now), isTrue);
      expect(
        matchesSalesQueue(client, tasks, SalesQueue.overdue, now),
        isFalse,
      );
      expect(
        matchesSalesQueue(client, tasks, SalesQueue.upcoming, now),
        isFalse,
      );
      expect(
        matchesSalesQueue(client, tasks, SalesQueue.noNextAction, now),
        isFalse,
      );
      expect(
        matchesSalesQueue(client, [], SalesQueue.noNextAction, now),
        isTrue,
      );
      expect(
        matchesSalesQueue(
          client.copyWith(stage: ClientStage.lost),
          [],
          SalesQueue.noNextAction,
          now,
        ),
        isTrue,
      );
      expect(
        matchesSalesQueue(
          client.copyWith(followUpAt: now),
          [],
          SalesQueue.today,
          now,
        ),
        isTrue,
      );
      final undatedTasks = <SalesTask>[
        (plan: plan.copyWith(taskWorkflow: {}), feature: tasks.first.feature),
      ];
      expect(
        matchesSalesQueue(client, undatedTasks, SalesQueue.noNextAction, now),
        isTrue,
      );
      for (final date in [
        null,
        DateTime(2026, 10, 1, 23, 59),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 2, 23, 59),
        DateTime(2026, 10, 3),
      ]) {
        final record = client.copyWith(followUpAt: date);
        expect(
          SalesQueue.values.where(
            (queue) => matchesSalesQueue(record, [], queue, now),
          ),
          hasLength(1),
        );
      }
    },
  );

  group('task workflow draft cycles', () {
    Plan restorePlan() => Plan(
      id: 'restore-plan',
      clientId: 'client',
      type: PlanType.setup,
      name: 'Plan',
      price: 100,
      features: const ['Content: Artwork'],
      startDate: DateTime(2026, 10, 1),
      taskWorkflow: const {
        'Content: Artwork': {
          'assignedTo': 'staff',
          'status': 'assigned',
          'priority': 'high',
          'internalNotes': 'Keep notes',
        },
      },
    );
    const restoreKey = 'Content: Artwork';

    test(
      'restores saved stage after serialization and repeated completion saves',
      () {
        for (final status in [
          TaskStatus.assigned,
          TaskStatus.started,
          TaskStatus.notAssigned,
        ]) {
          var plan = restorePlan();
          if (status == TaskStatus.notAssigned) {
            plan = updateTaskAssignment(plan, restoreKey, priority: 'high');
          }
          plan = setTaskStatus(plan, restoreKey, status);
          var completed = setTaskStatus(plan, restoreKey, TaskStatus.completed);
          completed = Plan.fromData(completed.id, completed.toFirestore());
          completed = setTaskStatus(
            completed,
            restoreKey,
            TaskStatus.completed,
          );
          final restored = restoreCompletedTask(completed, restoreKey);
          expect(taskStatus(restored, restoreKey), status);
          expect(taskCompletedAt(restored, restoreKey), isNull);
          expect(restored.taskWorkflow[restoreKey]?['completedBy'], isNull);
          expect(taskPriority(restored, restoreKey), 'high');
          expect(taskInternalNotes(restored, restoreKey), 'Keep notes');
          expect(restored.price, 100);
          final recompleted = setTaskStatus(
            restored,
            restoreKey,
            TaskStatus.completed,
          );
          expect(
            taskStatus(
              restoreCompletedTask(recompleted, restoreKey),
              restoreKey,
            ),
            status,
          );
        }
      },
    );

    test(
      'restores client review and preserves draft edits and earlier drafts',
      () {
        var plan = createNextDraftCycle(restorePlan(), restoreKey);
        plan = createNextDraftCycle(plan, restoreKey);
        plan = submitTaskForReview(plan, restoreKey, reviewer: 'client');
        final earlier = taskCycles(plan, restoreKey).first;
        var completed = completeReviewedTask(plan, restoreKey);
        completed = updateTaskCycleWorkLink(
          completed,
          restoreKey,
          2,
          'https://example.com/revised',
        );
        final restored = restoreCompletedTask(completed, restoreKey);
        expect(taskStatus(restored, restoreKey), TaskStatus.draftCycle);
        expect(
          draftCycleStage(restored, restoreKey),
          DraftCycleStage.confirmation,
        );
        expect(
          currentTaskCycle(restored, restoreKey)['reviewRequestedFrom'],
          'client',
        );
        expect(
          currentTaskCycle(restored, restoreKey)['clientConfirmed'],
          isFalse,
        );
        expect(currentTaskCycle(restored, restoreKey)['completedAt'], isNull);
        expect(
          currentTaskCycle(restored, restoreKey)['draftLink'],
          'https://example.com/revised',
        );
        expect(
          currentTaskCycle(restored, restoreKey)['sentToClientAt'],
          currentTaskCycle(plan, restoreKey)['sentToClientAt'],
        );
        expect(taskCycles(restored, restoreKey).first, earlier);
        expect(taskCycles(restored, restoreKey), hasLength(2));
      },
    );

    test('restores working draft stage for non-review completion', () {
      final plan = replaceTaskWorkflowCycles(restorePlan(), restoreKey, [
        {
          'cycle': 1,
          'status': TaskStatus.draftCycle.name,
          'draftStage': DraftCycleStage.working.name,
          'instructions': 'Keep instructions',
        },
      ]);
      final completed = setTaskStatus(plan, restoreKey, TaskStatus.completed);
      final restored = restoreCompletedTask(completed, restoreKey);
      expect(draftCycleStage(restored, restoreKey), DraftCycleStage.working);
      expect(
        taskText(restored, restoreKey, 'instructions'),
        'Keep instructions',
      );
    });

    test(
      'legacy completion restores to client review or recorded work stage',
      () {
        for (final started in [false, true]) {
          final original = restorePlan();
          final legacy = original.copyWith(
            taskWorkflow: {
              restoreKey: {
                ...original.taskWorkflow[restoreKey]!,
                'status': 'completed',
                if (started) 'firstStartedAt': '2026-10-01T10:00:00Z',
              },
            },
          );
          final restored = restoreCompletedTask(legacy, restoreKey);
          expect(
            taskStatus(restored, restoreKey),
            started ? TaskStatus.started : TaskStatus.assigned,
          );
        }
        final completed = completeReviewedTask(
          submitTaskForReview(restorePlan(), restoreKey, reviewer: 'client'),
          restoreKey,
        );
        final legacy = completed.copyWith(
          taskWorkflow: {
            restoreKey: {
              ...completed.taskWorkflow[restoreKey]!,
              'completionPreviousStage': null,
            },
          },
        );
        final restored = restoreCompletedTask(legacy, restoreKey);
        expect(taskStatus(restored, restoreKey), TaskStatus.draftCycle);
        expect(
          currentTaskCycle(restored, restoreKey)['reviewRequestedFrom'],
          'client',
        );
        expect(
          currentTaskCycle(restored, restoreKey)['clientConfirmed'],
          isFalse,
        );
      },
    );

    test(
      'restoring a split unit keeps other units and progress and pauses timer',
      () {
        final startedAt = DateTime.utc(2026, 10, 1, 10);
        final original = restorePlan();
        final plan = original.copyWith(
          completedFeatures: const [restoreKey],
          featureProgress: const {restoreKey: 100},
          taskWorkflow: {
            '$restoreKey#1': {
              ...original.taskWorkflow[restoreKey]!,
              'status': 'started',
              'timerRunning': true,
              'startedAt': startedAt.toIso8601String(),
              'elapsedMilliseconds': 1000,
            },
            '$restoreKey#2': {'status': 'completed', 'assignedTo': 'other'},
          },
        );
        final completed = setTaskStatus(
          plan,
          '$restoreKey#1',
          TaskStatus.completed,
          now: startedAt.add(const Duration(minutes: 1)),
        );
        final restored = restoreCompletedTask(
          completed,
          '$restoreKey#1',
          now: startedAt.add(const Duration(days: 1)),
        );
        expect(taskStatus(restored, '$restoreKey#1'), TaskStatus.started);
        expect(
          restored.taskWorkflow['$restoreKey#2'],
          plan.taskWorkflow['$restoreKey#2'],
        );
        expect(restored.completedFeatures, plan.completedFeatures);
        expect(restored.featureProgress, plan.featureProgress);
        expect(taskTimerIsRunning(restored, '$restoreKey#1'), isFalse);
        expect(
          taskElapsedTime(restored, '$restoreKey#1'),
          const Duration(seconds: 61),
        );
      },
    );

    test('restore rejects active tasks and invalid saved stages', () {
      expect(
        () => restoreCompletedTask(restorePlan(), restoreKey),
        throwsStateError,
      );
      final completed = setTaskStatus(
        restorePlan(),
        restoreKey,
        TaskStatus.completed,
      );
      final invalid = completed.copyWith(
        taskWorkflow: {
          restoreKey: {
            ...completed.taskWorkflow[restoreKey]!,
            'completionPreviousStage': {'status': 'invalid'},
          },
        },
      );
      expect(() => restoreCompletedTask(invalid, restoreKey), throwsStateError);
    });

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
      expect(taskCompletedAt(stopped, key), isNull);

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

      final completedAt = DateTime(2026, 9, 16, 12);
      final completed = setTaskStatus(
        plan,
        key,
        TaskStatus.completed,
        now: completedAt,
      );

      expect(taskStatus(completed, key), TaskStatus.completed);
      expect(taskCompletedAt(completed, key), completedAt.toUtc());
      expect(taskCycles(completed, key), hasLength(1));
      expect(completed.taskWorkflow[key]?['cycles'], isNull);

      final reopened = setTaskStatus(
        completed,
        key,
        TaskStatus.assigned,
        now: DateTime(2026, 9, 17),
      );
      expect(taskCompletedAt(reopened, key), isNull);
    });

    test('completing a draft cycle records its completion time', () {
      const key = 'content#1';
      final completedAt = DateTime(2026, 9, 16, 12);
      final plan = Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Starter',
        price: 0,
        features: const ['Content: 1 reel'],
        startDate: DateTime(2024, 1, 1),
        taskWorkflow: const {
          key: {
            'status': 'draftCycle',
            'cycles': [
              {'cycle': 1, 'status': 'draftCycle'},
            ],
          },
        },
      );

      final completed = replaceTaskWorkflowCycles(plan, key, const [
        {'cycle': 1, 'status': 'completed'},
      ], now: completedAt);

      expect(taskStatus(completed, key), TaskStatus.completed);
      expect(taskCompletedAt(completed, key), completedAt.toUtc());
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
