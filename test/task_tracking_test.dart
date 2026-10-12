import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/task_tracking_widgets.dart';

const _key = 'Content: Artwork';
final _admin = AppUser(uid: 'admin', email: '', name: 'Admin', isAdmin: true);
final _staff = AppUser(uid: 'staff', email: '', name: 'Staff', isAdmin: false);
final _createdAt = DateTime.utc(2026, 10, 9, 9);

Plan _plan() => Plan(
  id: 'plan',
  clientId: 'client',
  type: PlanType.setup,
  name: 'Plan',
  price: 0,
  startDate: DateTime(2026, 1, 1),
  features: const [_key],
);

Plan _assigned() => updateTaskAssignment(
  recordTaskCreation(_plan(), _key, actor: _admin, now: _createdAt),
  _key,
  assignedTo: 'staff',
  assignedToName: 'Staff',
  priority: 'normal',
  actor: _admin,
  now: _createdAt,
);

void main() {
  test('timer start advances assigned tasks but preserves review stages', () {
    var plan = setTaskTimerRunning(_assigned(), _key, true, now: _createdAt);
    expect(taskStatus(plan, _key), TaskStatus.started);
    plan = setTaskTimerRunning(
      plan,
      _key,
      false,
      now: _createdAt.add(const Duration(minutes: 1)),
    );
    expect(taskStatus(plan, _key), TaskStatus.started);
    for (final reviewer in ['admin', 'client']) {
      final submitted = submitTaskForReview(plan, _key, reviewer: reviewer);
      final working = setTaskTimerRunning(submitted, _key, true);
      expect(taskStatus(working, _key), TaskStatus.draftCycle);
      expect(currentTaskCycle(working, _key)['reviewRequestedFrom'], reviewer);
    }
  });

  test(
    'creation and assignment timestamps are stable and combine only when equal',
    () {
      var plan = _assigned();
      var events = taskTrackingEvents(plan, _key);
      expect(events.single.label, 'Created / assigned');
      expect(events.single.by, 'Admin');
      expect(events.single.at, _createdAt);
      plan = recordTaskCreation(
        plan,
        _key,
        actor: _staff,
        now: _createdAt.add(const Duration(days: 1)),
      );
      plan = updateTaskAssignment(
        plan,
        _key,
        assignedTo: 'staff',
        assignedToName: 'Staff',
        priority: 'urgent',
        actor: _staff,
        now: _createdAt.add(const Duration(days: 1)),
      );
      expect(taskTrackingEvents(plan, _key).single, events.single);
      plan = updateTaskAssignment(
        plan,
        _key,
        assignedTo: 'other',
        assignedToName: 'Other',
        priority: 'normal',
        actor: _admin,
        now: _createdAt.add(const Duration(days: 2)),
      );
      events = taskTrackingEvents(plan, _key);
      expect(events.map((event) => event.label), ['Created', 'Assigned']);
      expect(events.last.at, _createdAt.add(const Duration(days: 2)));
      expect(events.last.by, 'Admin');
    },
  );

  test('first started stays fixed across pause, resume, and status edits', () {
    var plan = setTaskTimerRunning(
      _assigned(),
      _key,
      true,
      actor: _staff,
      now: _createdAt,
    );
    plan = setTaskTimerRunning(
      plan,
      _key,
      false,
      actor: _staff,
      now: _createdAt.add(const Duration(minutes: 10)),
    );
    plan = setTaskTimerRunning(
      plan,
      _key,
      true,
      actor: _admin,
      now: _createdAt.add(const Duration(hours: 1)),
    );
    plan = setTaskStatus(
      plan,
      _key,
      TaskStatus.started,
      actor: _admin,
      now: _createdAt.add(const Duration(hours: 2)),
    );
    final first = taskTrackingEvents(
      plan,
      _key,
    ).firstWhere((event) => event.label == 'First started');
    expect(first.at, _createdAt);
    expect(first.by, 'Staff');
    expect(taskStartedAt(plan, _key), _createdAt.add(const Duration(hours: 1)));
    expect(
      taskElapsedTime(
        plan,
        _key,
        now: _createdAt.add(const Duration(hours: 1, minutes: 5)),
      ),
      const Duration(minutes: 15),
    );
    final statusStart = setTaskStatus(
      _assigned(),
      _key,
      TaskStatus.started,
      actor: _staff,
      now: _createdAt,
    );
    expect(taskTrackingEvents(statusStart, _key).last.label, 'First started');
  });

  test('approval times belong to each draft and edits do not replace them', () {
    var plan = submitTaskForReview(
      _assigned(),
      _key,
      reviewer: 'admin',
      actor: _staff,
      now: _createdAt,
    );
    plan = updateTaskCycleWorkLink(plan, _key, 1, 'https://example.com/draft');
    plan = submitTaskForReview(
      plan,
      _key,
      reviewer: 'admin',
      actor: _admin,
      now: _createdAt.add(const Duration(hours: 1)),
    );
    plan = submitTaskForReview(
      plan,
      _key,
      reviewer: 'client',
      actor: _admin,
      now: _createdAt.add(const Duration(hours: 2)),
    );
    expect(
      currentTaskCycle(plan, _key)['sentToAdminAt'],
      _createdAt.toIso8601String(),
    );
    expect(currentTaskCycle(plan, _key)['sentToAdminBy'], {
      'uid': 'staff',
      'name': 'Staff',
    });
    final clientAt = currentTaskCycle(plan, _key)['sentToClientAt'];
    plan = createNextDraftCycle(plan, _key);
    expect(currentTaskCycle(plan, _key)['sentToAdminAt'], isNull);
    plan = submitTaskForReview(
      plan,
      _key,
      reviewer: 'admin',
      actor: _staff,
      now: _createdAt.add(const Duration(days: 1)),
    );
    expect(taskCycles(plan, _key).first['sentToClientAt'], clientAt);
    final labels = taskTrackingEvents(plan, _key).map((event) => event.label);
    expect(
      labels,
      containsAll([
        'Draft 1 - Sent for admin approval',
        'Draft 1 - Sent for client approval',
        'Draft 2 - Sent for admin approval',
      ]),
    );
  });

  test(
    'completion records the confirming person and preserves the date on later saves',
    () {
      final completedAt = _createdAt.add(const Duration(days: 1));
      var plan = submitTaskForReview(
        _assigned(),
        _key,
        reviewer: 'client',
        actor: _admin,
        now: _createdAt,
      );
      plan = completeReviewedTask(plan, _key, actor: _admin, now: completedAt);
      plan = completeReviewedTask(
        plan,
        _key,
        actor: _staff,
        now: completedAt.add(const Duration(days: 1)),
      );
      expect(taskCompletedAt(plan, _key), completedAt);
      expect(taskTrackingEvents(plan, _key).last.by, 'Admin');
      expect(
        currentTaskCycle(plan, _key)['completedAt'],
        completedAt.toIso8601String(),
      );
      final reopened = createNextDraftCycle(plan, _key);
      expect(taskCompletedAt(reopened, _key), isNull);
      expect(
        taskTrackingEvents(reopened, _key).map((event) => event.label),
        contains('Draft 1 - Completed'),
      );
    },
  );

  test(
    'one approval action records one completion event without duplicate timestamps',
    () {
      final submitted = submitTaskForReview(
        _assigned(),
        _key,
        reviewer: 'client',
        actor: _admin,
      );
      final completed = completeReviewedTask(submitted, _key, actor: _admin);
      expect(
        currentTaskCycle(completed, _key)['completedAt'],
        completed.taskWorkflow[_key]?['completedAt'],
      );
      final completionEvents = taskTrackingEvents(
        completed,
        _key,
      ).where((event) => event.label.endsWith('Completed'));
      expect(completionEvents, hasLength(1));
    },
  );

  test(
    'legacy tasks have no invented creation, start, or submission dates',
    () {
      final old = _plan().copyWith(
        taskWorkflow: {
          _key: {
            'assignedTo': 'staff',
            'status': 'draftCycle',
            'draftStage': 'confirmation',
            'reviewRequestedFrom': 'admin',
            'updatedAt': _createdAt.toIso8601String(),
            'startedAt': _createdAt.toIso8601String(),
          },
        },
      );
      expect(taskTrackingEvents(old, _key), isEmpty);
    },
  );

  test(
    'saving legacy started and completed tasks does not invent event dates',
    () {
      for (final status in [TaskStatus.started, TaskStatus.completed]) {
        final old = _plan().copyWith(
          taskWorkflow: {
            _key: {'assignedTo': 'staff', 'status': status.name},
          },
        );
        final saved = setTaskStatus(
          old,
          _key,
          status,
          actor: _admin,
          now: _createdAt,
        );
        expect(taskTrackingEvents(saved, _key), isEmpty);
        final withDraft = old.copyWith(
          taskWorkflow: {
            _key: {
              ...old.taskWorkflow[_key]!,
              'cycles': [
                {'cycle': 1, 'status': status.name},
              ],
            },
          },
        );
        final draftSaved = replaceTaskWorkflowCycles(
          withDraft,
          _key,
          taskCycles(withDraft, _key),
          actor: _admin,
          now: _createdAt,
        );
        expect(taskTrackingEvents(draftSaved, _key), isEmpty);
      }
    },
  );

  test('unit previews inherit only creation from the original task', () {
    final events = taskTrackingEvents(_assigned(), '$_key#1');
    expect(events.single.label, 'Created');
    expect(events.single.at, _createdAt);
    expect(events.single.by, 'Admin');
  });

  testWidgets(
    'tracking section shows local dates, times, people, and all draft events',
    (tester) async {
      var plan = _assigned();
      plan = updateTaskManagementDetails(
        plan,
        _key,
        dueAt: _createdAt.add(const Duration(days: 3)),
        internalNotes: '',
        actor: _admin,
      );
      plan = setTaskTimerRunning(
        plan,
        _key,
        true,
        actor: _staff,
        now: _createdAt.add(const Duration(hours: 1)),
      );
      plan = submitTaskForReview(
        plan,
        _key,
        reviewer: 'admin',
        actor: _staff,
        now: _createdAt.add(const Duration(hours: 2)),
      );
      plan = submitTaskForReview(
        plan,
        _key,
        reviewer: 'client',
        actor: _admin,
        now: _createdAt.add(const Duration(hours: 3)),
      );
      plan = completeReviewedTask(
        plan,
        _key,
        actor: _admin,
        now: _createdAt.add(const Duration(days: 1)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskTrackingSection(plan: plan, workflowKey: _key),
          ),
        ),
      );
      expect(find.text('Tracking'), findsOneWidget);
      for (final label in [
        'Created / assigned',
        'Due',
        'First started',
        'Draft 1 - Sent for admin approval',
        'Draft 1 - Sent for client approval',
        'Completed',
      ]) {
        expect(find.textContaining('$label:'), findsOneWidget);
      }
      expect(find.textContaining(' - Staff'), findsNWidgets(2));
      expect(find.textContaining(' - Admin'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cards show only dates relevant to current status', (
    tester,
  ) async {
    var plan = updateTaskManagementDetails(
      _assigned(),
      _key,
      dueAt: _createdAt.add(const Duration(days: 3)),
      internalNotes: '',
    );
    Future<String> cardDates() async {
      String result = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = taskCardDates(context, plan, _key);
              return Text(result);
            },
          ),
        ),
      );
      return result;
    }

    await cardDates();
    final expectedAt = _createdAt.toLocal();
    String expectedTimestamp(BuildContext context) =>
        '${MaterialLocalizations.of(context).formatMediumDate(expectedAt)}, '
        '${TimeOfDay.fromDateTime(expectedAt).format(context)}';
    final context = tester.element(find.byType(Text).first);
    final timestamp = expectedTimestamp(context);
    expect(await cardDates(), 'Created on $timestamp');
    plan = setTaskTimerRunning(
      plan,
      _key,
      true,
      now: _createdAt,
      actor: _staff,
    );
    expect(await cardDates(), 'Started on $timestamp');
    plan = setTaskTimerRunning(plan, _key, false, now: _createdAt);
    plan = createNextDraftCycle(plan, _key, actor: _staff, now: _createdAt);
    expect(await cardDates(), 'Draft 1 - Created on $timestamp');
    plan = submitTaskForReview(
      plan,
      _key,
      reviewer: 'admin',
      actor: _staff,
      now: _createdAt,
    );
    expect(
      await cardDates(),
      'Draft 1 - Sent for admin approval on $timestamp',
    );
    plan = submitTaskForReview(
      plan,
      _key,
      reviewer: 'client',
      actor: _admin,
      now: _createdAt,
    );
    expect(
      await cardDates(),
      'Draft 1 - Sent for client approval on $timestamp',
    );
    plan = completeReviewedTask(plan, _key, actor: _admin, now: _createdAt);
    expect(await cardDates(), 'Completed on $timestamp');
  });
}
