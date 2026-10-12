import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/task_save_controller.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/task_save_feedback.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';

const _feature = 'Content / Content: Artwork';

Plan _plan() => Plan(
  id: 'plan',
  clientId: 'client',
  type: PlanType.setup,
  name: 'Plan',
  price: 0,
  features: const [_feature],
  startDate: DateTime(2026, 10, 9),
  taskWorkflow: const {
    _feature: {
      'status': 'assigned',
      'assignedTo': 'staff',
      'assignedToName': 'Staff',
    },
  },
);

class _DelayedService implements FirestoreService {
  final writes = <Plan>[];
  Completer<void> acknowledgement = Completer<void>();

  @override
  Future<void> updatePlan(Plan plan, {Plan? previous}) {
    writes.add(plan);
    return acknowledgement.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  final String uid;
  _User(this.uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _showBoard(WidgetTester tester, _DelayedService service) async {
  final before = _plan();
  final admin = AppUser(uid: 'admin', email: '', name: 'Admin', isAdmin: true);
  final staff = AppUser(uid: 'staff', email: '', name: 'Staff', isAdmin: false);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        currentUserProfileProvider.overrideWith((ref) async => admin),
        firestoreServiceProvider.overrideWithValue(service),
        allPlansStreamProvider.overrideWith((ref) => Stream.value([before])),
        allUsersProvider.overrideWith((ref) => Stream.value([admin, staff])),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            final plan =
                ref.watch(visiblePlansProvider).valueOrNull?.single ?? before;
            return Scaffold(
              body: Column(
                children: [
                  const TaskSaveFeedback(),
                  TaskRow(
                    task: TaskItem(
                      rawFeature: plan.features.single,
                      plan: plan,
                    ),
                    category: 'Content',
                    clientName: 'Client',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('normal save displays the edited title before acknowledgement', (
    tester,
  ) async {
    final service = _DelayedService();
    await _showBoard(tester, service);
    await tester.tap(find.text('Artwork'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Task title'),
      'Revised artwork',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskWorkflowDialog), findsNothing);
    expect(find.text('Revised artwork'), findsOneWidget);
    expect(find.text('Saving...'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TaskSaveFeedback),
        matching: find.textContaining('Saving'),
      ),
      findsNothing,
    );
    expect(find.text('Refresh list'), findsNothing);
    service.acknowledgement.completeError(StateError('Write denied'));
    await tester.pumpAndSettle();
    expect(find.text('Artwork'), findsOneWidget);
    expect(find.text('Revised artwork'), findsNothing);
    expect(find.text('Retry save'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final action in {
    'Archive task': 'Restore task',
    'Start work': 'Stop work',
  }.entries) {
    testWidgets('${action.key} changes immediately and restores on rejection', (
      tester,
    ) async {
      final service = _DelayedService();
      await _showBoard(tester, service);
      await tester.tap(find.byTooltip(action.key));
      await tester.pumpAndSettle();
      expect(find.byTooltip(action.value), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == action.value,
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Saving...'), findsOneWidget);
      service.acknowledgement.completeError(StateError('Write denied'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(action.key), findsOneWidget);
      expect(find.text('Retry save'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test(
    'creation retry is idempotent and cannot overwrite an existing changed plan',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: firestore);
      final desired = _plan();
      await service.createPlan(desired, ifAbsent: true);
      await service.createPlan(desired, ifAbsent: true);
      final doc = firestore.collection('plans').doc(desired.id);
      await doc.update({'price': 500});
      await expectLater(
        service.createPlan(desired, ifAbsent: true),
        throwsStateError,
      );
      expect(Plan.fromFirestore(await doc.get()).price, 500);
    },
  );

  test(
    'newer edits received before acknowledgement are not hidden afterwards',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = updateTaskManagementDetails(
        before,
        _feature,
        dueAt: null,
        internalNotes: 'My edits',
      );
      final ack = Completer<void>();
      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: () => ack.future,
      );
      controller.reconcile([desired]);
      final newer = updateTaskManagementDetails(
        desired,
        _feature,
        dueAt: null,
        internalNotes: 'Someone edited it afterwards',
      );
      controller.reconcile([newer]);
      ack.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isEmpty);
      expect(controller.visiblePlans([newer]).single, same(newer));
    },
  );

  test(
    'account switching clears pending saves without restarting list on each save',
    () async {
      final auth = StreamController<User?>();
      final plans = StreamController<List<Plan>>();
      var subscriptions = 0;
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => auth.stream),
          allPlansStreamProvider.overrideWith((ref) {
            subscriptions++;
            return plans.stream;
          }),
        ],
      );
      final listener = container.listen(visiblePlansProvider, (_, _) {});
      addTearDown(() async {
        listener.close();
        container.dispose();
        await auth.close();
        await plans.close();
      });
      auth.add(_User('first'));
      plans.add([_plan()]);
      await Future<void>.delayed(Duration.zero);
      final before = _plan();
      final desired = setTaskStatus(before, _feature, TaskStatus.started);
      final ack = Completer<void>();
      container
          .read(taskSavesProvider.notifier)
          .submit(
            desired: desired,
            previous: before,
            label: 'Artwork',
            persist: () => ack.future,
          );
      expect(
        container.read(visiblePlansProvider).requireValue.single,
        same(desired),
      );
      expect(subscriptions, 1);
      auth.add(_User('second'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(taskSavesProvider), isEmpty);
      ack.complete();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(taskSavesProvider), isEmpty);
      expect(
        container.read(visiblePlansProvider).requireValue.single,
        isNot(same(desired)),
      );
    },
  );

  test(
    'shows submitted state immediately, and waits for both ack and snapshot',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = setTaskStatus(before, _feature, TaskStatus.started);
      final ack = Completer<void>();
      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: () => ack.future,
      );
      expect(controller.visiblePlans([before]).single, same(desired));
      expect(controller.state['plan']!.phase, TaskSavePhase.saving);
      controller.reconcile([desired]);
      expect(controller.state['plan']!.phase, TaskSavePhase.saving);
      ack.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isEmpty);
      final remoteEdit = desired.copyWith(price: 500);
      expect(controller.visiblePlans([remoteEdit]).single.price, 500);
    },
  );

  test(
    'ack before snapshot retains immediate state until live data catches up',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = setTaskStatus(before, _feature, TaskStatus.started);
      controller.reconcile([before]);
      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: () async {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state['plan']!.phase, TaskSavePhase.confirmed);
      expect(controller.visiblePlans([before]).single, same(desired));
      controller.reconcile([desired.copyWith(price: 500)]);
      expect(controller.state, isEmpty);
    },
  );

  test(
    'failure rolls back; retry keeps exact edits and blocks duplicate writes',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = updateTaskManagementDetails(
        before,
        _feature,
        dueAt: null,
        internalNotes: 'Keep these edits',
      );
      var calls = 0;
      var ack = Completer<void>();
      Future<void> persist() {
        calls++;
        return ack.future;
      }

      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: persist,
      );
      expect(
        () => controller.submit(
          desired: desired,
          previous: before,
          label: 'Duplicate',
          persist: persist,
        ),
        throwsStateError,
      );
      ack.completeError(StateError('Network unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.visiblePlans([desired]).single, same(before));
      expect(controller.state['plan']!.desired, same(desired));
      expect(
        controller.state['plan']!.error.toString(),
        contains('Network unavailable'),
      );
      ack = Completer<void>();
      controller.retry('plan');
      expect(calls, 2);
      expect(controller.visiblePlans([before]).single, same(desired));
      ack.complete();
      await Future<void>.delayed(Duration.zero);
      controller.reconcile([desired]);
      expect(controller.state, isEmpty);
    },
  );

  test('failed creation is hidden but retained for retry/discard', () async {
    final controller = TaskSaveController();
    addTearDown(controller.dispose);
    controller.submit(
      desired: _plan(),
      previous: null,
      label: 'New task',
      persist: () => Future.error(StateError('Denied')),
    );
    expect(controller.visiblePlans([]), hasLength(1));
    await Future<void>.delayed(Duration.zero);
    expect(controller.visiblePlans([_plan()]), isEmpty);
    expect(controller.state['plan']!.phase, TaskSavePhase.failed);
    controller.discard('plan');
    expect(controller.state, isEmpty);
  });

  test('completion updates both lists before confirmation', () async {
    final controller = TaskSaveController();
    addTearDown(controller.dispose);
    final before = _plan();
    final completed = setTaskStatus(before, _feature, TaskStatus.completed);
    final ack = Completer<void>();
    controller.submit(
      desired: completed,
      previous: before,
      label: 'Artwork',
      persist: () => ack.future,
    );
    final visible = controller.visiblePlans([before]);
    expect(taskStatus(visible.single, _feature), TaskStatus.completed);
    ack.completeError(StateError('Denied'));
    await Future<void>.delayed(Duration.zero);
    expect(
      taskStatus(controller.visiblePlans([before]).single, _feature),
      TaskStatus.assigned,
    );
  });

  test('disposed session ignores old acknowledgements and errors', () async {
    final ack = Completer<void>();
    var confirmed = 0;
    final old = TaskSaveController(onConfirmed: (_) => confirmed++);
    old.submit(
      desired: _plan(),
      previous: null,
      label: 'Old account',
      persist: () => ack.future,
    );
    old.dispose();
    ack.completeError(StateError('Old account denied'));
    await Future<void>.delayed(Duration.zero);
    expect(confirmed, 0);
    final next = TaskSaveController();
    expect(next.state, isEmpty);
    next.dispose();
  });

  test(
    'transaction preserves concurrent unrelated task edits and rejects conflicts',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: firestore);
      final before = _plan();
      final doc = firestore.collection('plans').doc(before.id);
      final concurrent = before.copyWith(
        price: 500,
        taskWorkflow: {
          ...before.taskWorkflow,
          'Other task': {'internalNotes': 'Live notes'},
        },
      );
      await doc.set(concurrent.toFirestore());
      final desired = updateTaskManagementDetails(
        before,
        _feature,
        dueAt: null,
        internalNotes: 'My edits',
      );
      await service.updatePlan(desired, previous: before);
      var saved = Plan.fromFirestore(await doc.get());
      expect(saved.price, 500);
      expect(saved.taskWorkflow['Other task']!['internalNotes'], 'Live notes');
      expect(taskInternalNotes(saved, _feature), 'My edits');
      await service.updatePlan(desired, previous: before);
      final conflicting = updateTaskManagementDetails(
        before,
        _feature,
        dueAt: null,
        internalNotes: 'Stale edits',
      );
      await expectLater(
        service.updatePlan(conflicting, previous: before),
        throwsStateError,
      );
      saved = Plan.fromFirestore(await doc.get());
      expect(taskInternalNotes(saved, _feature), 'My edits');
    },
  );

  testWidgets(
    'review closes editor immediately and retry is visible after delayed rejection',
    (tester) async {
      final service = _DelayedService();
      final before = _plan();
      final profile = AppUser(
        uid: 'admin',
        email: 'admin@example.com',
        name: 'Admin',
        isAdmin: true,
        isStaff: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            currentUserProfileProvider.overrideWith((ref) async => profile),
            firestoreServiceProvider.overrideWithValue(service),
            allPlansStreamProvider.overrideWith(
              (ref) => Stream.value([before]),
            ),
            allUsersProvider.overrideWith(
              (ref) => Stream.value([
                profile,
                AppUser(
                  uid: 'staff',
                  email: 'staff@example.com',
                  name: 'Staff',
                  isAdmin: false,
                  isStaff: true,
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final plans =
                    ref.watch(visiblePlansProvider).valueOrNull ?? [before];
                return Scaffold(
                  body: Column(
                    children: [
                      const TaskSaveFeedback(),
                      TaskRow(
                        task: TaskItem(
                          rawFeature: _feature,
                          plan: plans.single,
                        ),
                        category: 'Content',
                        clientName: 'Client',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send for admin approval'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskWorkflowDialog), findsNothing);
      expect(find.text('Saving...'), findsOneWidget);
      expect(find.text('Waiting for admin approval'), findsOneWidget);
      expect(service.writes, hasLength(1));
      await tester.pump(const Duration(seconds: 16));
      expect(find.textContaining('not confirmed yet'), findsOneWidget);
      service.acknowledgement.completeError(StateError('Network unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for admin approval'), findsNothing);
      expect(find.text('Retry save'), findsOneWidget);
      service.acknowledgement = Completer<void>();
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(find.text('Saving...'), findsOneWidget);
      expect(service.writes, hasLength(2));
      expect(
        service.writes.first.toFirestore(),
        service.writes.last.toFirestore(),
      );
      service.acknowledgement.complete();
      await tester.pumpAndSettle();
      expect(find.text('Saving...'), findsNothing);
      expect(find.text('Refresh list'), findsNothing);
      expect(find.textContaining('Saved - updating list'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
