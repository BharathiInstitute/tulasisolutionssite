import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';
import 'package:tulasisolutionssite/core/widgets/task_save_feedback.dart';

const _feature = 'Content / Content: Review artwork';

Finder _notesField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.labelText == 'Internal project notes',
);

Finder _restoreConfirmationField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.labelText == 'Type RESTORE to confirm',
);

Plan _assignedPlan() => Plan(
  id: 'plan',
  clientId: 'client',
  type: PlanType.setup,
  name: 'Plan',
  price: 0,
  features: const [_feature],
  startDate: DateTime(2026, 10, 9),
  taskWorkflow: const {
    _feature: {
      'assignedTo': 'staff',
      'assignedToName': 'Staff with a very long name for the status label',
      'status': 'assigned',
    },
  },
);

class _ReviewService implements FirestoreService {
  final savedPlans = <Plan>[];
  bool failSave = false;

  @override
  Future<void> updatePlan(Plan plan, {Plan? previous}) async {
    if (failSave) throw StateError('Connection unavailable');
    savedPlans.add(plan);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppUser _profile({bool admin = false}) => AppUser(
  uid: admin ? 'admin' : 'staff',
  email: admin ? 'admin@example.com' : 'staff@example.com',
  name: admin ? 'Admin' : 'Staff',
  isAdmin: admin,
  isStaff: true,
  panels: const ['myTasks'],
);

Future<void> _showDialog(
  WidgetTester tester,
  Plan plan,
  _ReviewService service, {
  bool admin = false,
  bool personal = false,
  bool ownsTask = true,
}) async {
  final profile = _profile(admin: admin);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProfileProvider.overrideWith((ref) async => profile),
        currentStaffIdsProvider.overrideWith(
          (ref) => ownsTask ? ['staff'] : ['another-staff'],
        ),
        firestoreServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, child) => Scaffold(
            body: Column(
              children: [
                const TaskSaveFeedback(),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => TaskWorkflowDialog(
                      task: TaskItem(rawFeature: _feature, plan: plan),
                      clientName: 'Client',
                      ref: ref,
                      staff: [_profile()],
                      lockedAssigneeId: personal ? 'staff' : null,
                    ),
                  ),
                  child: const Text('Open task'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open task'));
  await tester.pumpAndSettle();
}

Future<void> _showRow(
  WidgetTester tester,
  Plan plan, {
  bool personal = false,
  int? unitIndex,
  int? unitTotal,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      currentUserProfileProvider.overrideWith((ref) async => null),
      allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: TaskRow(
          task: TaskItem(
            rawFeature: _feature,
            plan: plan,
            unitIndex: unitIndex,
            unitTotal: unitTotal,
          ),
          category: 'Content',
          clientName: 'Client',
          lockedAssigneeId: personal ? 'staff' : null,
        ),
      ),
    ),
  ),
);

void main() {
  for (final number in [1, 2, 3, 5]) {
    for (final admin in [false, true]) {
      testWidgets('draft $number repeats approval buttons: admin=$admin', (
        tester,
      ) async {
        var plan = _assignedPlan();
        for (var draft = 0; draft < number; draft++) {
          plan = createNextDraftCycle(plan, _feature);
        }
        final service = _ReviewService();
        await _showDialog(
          tester,
          plan,
          service,
          admin: admin,
          personal: !admin,
        );
        expect(find.text('Send for admin approval'), findsOneWidget);
        expect(find.text('Send to client for approval'), findsNothing);
        expect(find.text('Complete'), findsNothing);
        await tester.tap(find.text('Send for admin approval'));
        await tester.pumpAndSettle();
        final submitted = service.savedPlans.single;
        expect(currentTaskCycle(submitted, _feature)['cycle'], number);
        expect(
          currentTaskCycle(submitted, _feature)['reviewRequestedFrom'],
          'admin',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _showDialog(tester, submitted, service, admin: true);
        expect(find.text('Send for admin approval'), findsNothing);
        expect(find.text('Send to client for approval'), findsOneWidget);
        expect(find.text('Complete'), findsNothing);
        await tester.tap(find.text('Send to client for approval'));
        await tester.pumpAndSettle();
        final sentToClient = service.savedPlans.last;
        expect(currentTaskCycle(sentToClient, _feature)['cycle'], number);
        expect(
          currentTaskCycle(sentToClient, _feature)['reviewRequestedFrom'],
          'client',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _showDialog(tester, sentToClient, service, admin: true);
        expect(
          find.text('Client approved - move to Completed'),
          findsOneWidget,
        );
        expect(find.text('Send to client for approval'), findsNothing);
        expect(find.text('Complete'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'list cards show a separate automatic status including completion',
    (tester) async {
      var plan = _assignedPlan();
      await _showRow(tester, plan);
      expect(find.text('Assigned'), findsOneWidget);
      plan = setTaskTimerRunning(plan, _feature, true);
      await _showRow(tester, plan);
      expect(find.text('Working'), findsOneWidget);
      plan = setTaskTimerRunning(plan, _feature, false);
      await _showRow(tester, plan);
      expect(find.text('Started'), findsOneWidget);
      plan = submitTaskForReview(plan, _feature, reviewer: 'admin');
      await _showRow(tester, plan);
      expect(find.text('Waiting for admin approval'), findsOneWidget);
      expect(find.text('Draft cycle'), findsNothing);
      plan = completeReviewedTask(plan, _feature);
      await _showRow(tester, plan);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Waiting for admin approval'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'staff sends an assigned task and current edits for admin approval',
    (tester) async {
      final service = _ReviewService();
      await _showDialog(tester, _assignedPlan(), service, personal: true);
      expect(find.text('Send for admin approval'), findsOneWidget);
      expect(find.text('Send to client for approval'), findsNothing);
      expect(find.text('Approve and complete'), findsNothing);
      await tester.enterText(_notesField(), 'Ready to review');
      await tester.tap(find.text('Send for admin approval'));
      await tester.pumpAndSettle();
      final saved = service.savedPlans.single;
      expect(taskStatus(saved, _feature), TaskStatus.draftCycle);
      expect(draftCycleStage(saved, _feature), DraftCycleStage.confirmation);
      expect(currentTaskCycle(saved, _feature)['reviewRequestedFrom'], 'admin');
      expect(currentTaskCycle(saved, _feature)['sentToAdminAt'], isNotNull);
      expect(currentTaskCycle(saved, _feature)['sentToAdminBy'], {
        'uid': 'staff',
        'name': 'Staff',
      });
      expect(currentTaskCycle(saved, _feature)['cycle'], 1);
      expect(taskInternalNotes(saved, _feature), 'Ready to review');
      expect(taskAssigneeName(saved, _feature), _profile().name);
      expect(find.byType(TaskWorkflowDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('staff submission saves a new draft link and instructions', (
    tester,
  ) async {
    final service = _ReviewService();
    await _showDialog(tester, _assignedPlan(), service, personal: true);
    await tester.ensureVisible(find.text('New draft'));
    await tester.tap(find.text('New draft'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draft-instructions-1')),
      'Review the artwork',
    );
    await tester.enterText(
      find.byKey(const ValueKey('draft-link-1')),
      'https://example.com/draft',
    );
    await tester.tap(find.text('Send for admin approval'));
    await tester.pumpAndSettle();
    final draft = currentTaskCycle(service.savedPlans.single, _feature);
    expect(draft['instructions'], 'Review the artwork');
    expect(draft['draftLink'], 'https://example.com/draft');
    expect(draft['reviewRequestedFrom'], 'admin');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'admin sends the latest submitted draft to client with unsaved edits',
    (tester) async {
      final service = _ReviewService();
      var plan = submitTaskForReview(
        _assignedPlan(),
        _feature,
        reviewer: 'admin',
      );
      plan = createNextDraftCycle(plan, _feature);
      plan = submitTaskForReview(plan, _feature, reviewer: 'admin');
      await _showDialog(tester, plan, service, admin: true);
      expect(find.text('Waiting for admin approval'), findsOneWidget);
      expect(find.text('Request changes'), findsOneWidget);
      expect(find.text('Send to client for approval'), findsOneWidget);
      expect(find.text('Send for admin approval'), findsNothing);
      expect(find.text('Approve and complete'), findsNothing);
      expect(find.text('Complete'), findsNothing);
      expect(find.text('Client approved - move to Completed'), findsNothing);
      expect(find.byType(DropdownButtonFormField<TaskStatus>), findsNothing);
      await tester.enterText(_notesField(), 'Send this revision');
      await tester.enterText(
        find.byKey(const ValueKey('draft-link-2')),
        'https://example.com/revised',
      );
      await tester.tap(find.text('Send to client for approval'));
      await tester.pumpAndSettle();
      final saved = service.savedPlans.single;
      expect(taskInternalNotes(saved, _feature), 'Send this revision');
      expect(currentTaskCycle(saved, _feature)['cycle'], 2);
      expect(
        currentTaskCycle(saved, _feature)['draftLink'],
        'https://example.com/revised',
      );
      expect(
        currentTaskCycle(saved, _feature)['reviewRequestedFrom'],
        'client',
      );
      expect(currentTaskCycle(saved, _feature)['sentToClientAt'], isNotNull);
      expect(currentTaskCycle(saved, _feature)['sentToClientBy'], {
        'uid': 'admin',
        'name': 'Admin',
      });
      expect(taskStatus(saved, _feature), TaskStatus.draftCycle);
      await tester.pumpWidget(const SizedBox.shrink());
      await _showRow(tester, saved);
      expect(find.text('Waiting for client approval'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final decision in [
    'Request changes',
    'Client approved - move to Completed',
  ]) {
    testWidgets('admin review action saves edits: $decision', (tester) async {
      final service = _ReviewService();
      final plan = submitTaskForReview(
        _assignedPlan(),
        _feature,
        reviewer: decision == 'Request changes' ? 'admin' : 'client',
      );
      await _showDialog(tester, plan, service, admin: true);
      if (decision != 'Request changes') {
        expect(find.text('Waiting for client approval'), findsOneWidget);
        expect(find.text('Send to client for approval'), findsNothing);
        expect(find.text('Complete'), findsNothing);
      }
      await tester.enterText(_notesField(), 'Review notes');
      await tester.ensureVisible(find.text(decision));
      await tester.tap(find.text(decision));
      await tester.pumpAndSettle();
      final saved = service.savedPlans.single;
      expect(taskInternalNotes(saved, _feature), 'Review notes');
      if (decision == 'Request changes') {
        expect(currentTaskCycle(saved, _feature)['cycle'], 2);
        expect(
          currentTaskCycle(saved, _feature)['reviewRequestedFrom'],
          isNull,
        );
        expect(draftCycleStage(saved, _feature), DraftCycleStage.instructions);
      } else {
        expect(taskStatus(saved, _feature), TaskStatus.completed);
        expect(currentTaskCycle(saved, _feature)['clientConfirmed'], isTrue);
        expect(saved.taskWorkflow[_feature]?['completedBy'], {
          'uid': 'admin',
          'name': 'Admin',
        });
        expect(
          TaskItem(rawFeature: _feature, plan: saved).isWorkflowCompleted,
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _showRow(tester, saved);
        expect(find.byIcon(Icons.pending_actions), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'completed preview is read-only and restore requires exact typed confirmation',
    (tester) async {
      final service = _ReviewService();
      final plan = completeReviewedTask(
        submitTaskForReview(_assignedPlan(), _feature, reviewer: 'client'),
        _feature,
      );
      await _showDialog(tester, plan, service, admin: true);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('New draft'), findsNothing);
      expect(find.byTooltip('Delete draft'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.readOnly),
        isTrue,
      );
      expect(
        tester
            .widgetList<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .every((field) => field.onChanged == null),
        isTrue,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Set due date'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Restore previous stage'));
      await tester.pumpAndSettle();
      expect(find.text('Restore completed task?'), findsOneWidget);
      final restoreButton = find.widgetWithText(FilledButton, 'Restore task');
      expect(tester.widget<FilledButton>(restoreButton).onPressed, isNull);
      for (final text in ['restore', 'RESTOR', ' RESTORE', 'RESTORE ']) {
        await tester.enterText(_restoreConfirmationField(), text);
        await tester.pump();
        expect(tester.widget<FilledButton>(restoreButton).onPressed, isNull);
        expect(service.savedPlans, isEmpty);
      }
      await tester.enterText(_restoreConfirmationField(), 'RESTORE');
      await tester.pump();
      expect(tester.widget<FilledButton>(restoreButton).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(service.savedPlans, isEmpty);
      expect(find.byType(TaskWorkflowDialog), findsOneWidget);
      await tester.tap(find.text('Restore previous stage'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(restoreButton).onPressed, isNull);
      await tester.enterText(_restoreConfirmationField(), 'RESTORE');
      await tester.pump();
      await tester.tap(find.text('Restore task'));
      await tester.pumpAndSettle();
      final saved = service.savedPlans.single;
      expect(taskStatus(saved, _feature), TaskStatus.draftCycle);
      expect(
        taskInternalNotes(saved, _feature),
        taskInternalNotes(plan, _feature),
      );
      expect(
        taskAssigneeName(saved, _feature),
        taskAssigneeName(plan, _feature),
      );
      expect(saved.features, plan.features);
      expect(taskPriority(saved, _feature), taskPriority(plan, _feature));
      expect(currentTaskCycle(saved, _feature)['clientConfirmed'], isFalse);
      expect(taskCompletedAt(saved, _feature), isNull);
      expect(find.byType(TaskWorkflowDialog), findsNothing);
      expect(
        TaskItem(rawFeature: _feature, plan: saved).isWorkflowCompleted,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _showRow(tester, saved);
      expect(find.text('Waiting for client approval'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'restore is hidden without completion permission and in personal previews',
    (tester) async {
      final completed = setTaskStatus(
        _assignedPlan(),
        _feature,
        TaskStatus.completed,
      );
      for (final personal in [false, true]) {
        await _showDialog(
          tester,
          completed,
          _ReviewService(),
          admin: personal,
          personal: personal,
        );
        expect(find.text('Restore previous stage'), findsNothing);
        expect(find.text('Save changes'), findsNothing);
        expect(find.text('New draft'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('failed restoration uses existing save recovery', (tester) async {
    final service = _ReviewService()..failSave = true;
    final completed = setTaskStatus(
      _assignedPlan(),
      _feature,
      TaskStatus.completed,
    );
    await _showDialog(tester, completed, service, admin: true);
    await tester.tap(find.text('Restore previous stage'));
    await tester.pumpAndSettle();
    await tester.enterText(_restoreConfirmationField(), 'RESTORE');
    await tester.pump();
    await tester.tap(find.text('Restore task'));
    await tester.pumpAndSettle();
    expect(find.text('Retry save'), findsOneWidget);
    expect(service.savedPlans, isEmpty);
    service.failSave = false;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(
      taskStatus(service.savedPlans.single, _feature),
      TaskStatus.assigned,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'pending reviews show their status and hide repeat send buttons',
    (tester) async {
      for (final reviewer in ['admin', 'client']) {
        final plan = submitTaskForReview(
          _assignedPlan(),
          _feature,
          reviewer: reviewer,
        );
        final service = _ReviewService();
        await _showDialog(tester, plan, service, personal: true);
        expect(find.text('Send for admin approval'), findsNothing);
        expect(find.text('Send to client for approval'), findsNothing);
        expect(
          find.text(
            reviewer == 'admin'
                ? 'Waiting for admin approval'
                : 'Waiting for client approval',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('staff cannot submit a task assigned to another staff member', (
    tester,
  ) async {
    final service = _ReviewService();
    await _showDialog(
      tester,
      _assignedPlan(),
      service,
      personal: true,
      ownsTask: false,
    );
    expect(find.text('Send for admin approval'), findsNothing);
    expect(find.text('Send to client for approval'), findsNothing);
    expect(service.savedPlans, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed submission retains edits and allows retry on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = _ReviewService()..failSave = true;
    await _showDialog(tester, _assignedPlan(), service, personal: true);
    await tester.enterText(_notesField(), 'Keep these notes');
    await tester.tap(find.text('Send for admin approval'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskWorkflowDialog), findsNothing);
    expect(find.textContaining('Save failed.'), findsOneWidget);
    expect(service.savedPlans, isEmpty);
    expect(tester.takeException(), isNull);
    service.failSave = false;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(
      taskInternalNotes(service.savedPlans.single, _feature),
      'Keep these notes',
    );
    expect(find.byType(TaskWorkflowDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final personal in [false, true]) {
    testWidgets('task card shows admin approval badge: personal=$personal', (
      tester,
    ) async {
      final submitted = submitTaskForReview(
        _assignedPlan(),
        _feature,
        reviewer: 'admin',
      );
      await _showRow(tester, submitted, personal: personal);
      expect(find.text('Waiting for admin approval'), findsOneWidget);
      expect(find.text('Waiting for client approval'), findsNothing);
      expect(find.byIcon(Icons.pending_actions), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('task card updates approval badge through the review lifecycle', (
    tester,
  ) async {
    var plan = _assignedPlan();
    await _showRow(tester, plan);
    expect(find.byIcon(Icons.pending_actions), findsNothing);

    plan = submitTaskForReview(plan, _feature, reviewer: 'admin');
    await _showRow(tester, plan);
    expect(find.text('Waiting for admin approval'), findsOneWidget);

    plan = submitTaskForReview(plan, _feature, reviewer: 'client');
    await _showRow(tester, plan);
    expect(find.text('Waiting for client approval'), findsOneWidget);
    expect(find.text('Waiting for admin approval'), findsNothing);

    final revised = createNextDraftCycle(plan, _feature);
    await _showRow(tester, revised);
    expect(find.byIcon(Icons.pending_actions), findsNothing);

    final completed = completeReviewedTask(plan, _feature);
    await _showRow(tester, completed);
    expect(find.byIcon(Icons.pending_actions), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'task card does not show approval for confirmed or unsent drafts',
    (tester) async {
      for (final cycle in [
        {'cycle': 1, 'status': 'draftCycle', 'draftStage': 'confirmation'},
        {
          'cycle': 1,
          'status': 'draftCycle',
          'draftStage': 'confirmation',
          'reviewRequestedFrom': 'admin',
          'clientConfirmed': true,
        },
        {
          'cycle': 1,
          'status': 'draftCycle',
          'draftStage': 'working',
          'reviewRequestedFrom': 'admin',
        },
      ]) {
        final plan = replaceTaskWorkflowCycles(_assignedPlan(), _feature, [
          cycle,
        ]);
        await _showRow(tester, plan);
        expect(find.byIcon(Icons.pending_actions), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'task approval badge uses the latest cycle and unit workflow key',
    (tester) async {
      const key = '$_feature#1';
      final plan = _assignedPlan().copyWith(
        taskWorkflow: {
          key: {
            'assignedTo': 'staff',
            'cycles': [
              {
                'cycle': 1,
                'status': 'draftCycle',
                'draftStage': 'confirmation',
                'reviewRequestedFrom': 'admin',
              },
              {
                'cycle': 2,
                'status': 'draftCycle',
                'draftStage': 'confirmation',
                'reviewRequestedFrom': 'client',
              },
            ],
          },
        },
      );
      await _showRow(tester, plan, unitIndex: 1, unitTotal: 2);
      expect(find.text('Waiting for client approval'), findsOneWidget);
      expect(find.text('Waiting for admin approval'), findsNothing);
      await _showRow(tester, plan, unitIndex: 2, unitTotal: 2);
      expect(find.byIcon(Icons.pending_actions), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('approval badge stays visible without overflow on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final submitted = submitTaskForReview(
      _assignedPlan(),
      _feature,
      reviewer: 'admin',
    );
    await _showRow(tester, submitted);
    final badge = find.text('Waiting for admin approval');
    expect(badge, findsOneWidget);
    expect(tester.getRect(badge).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(badge).right, lessThanOrEqualTo(390));
    expect(tester.widget<Text>(badge).overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
