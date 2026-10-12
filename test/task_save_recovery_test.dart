import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/plan_changes.dart';
import 'package:tulasisolutionssite/core/tasks/task_save_controller.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/task_save_feedback.dart';
import 'package:tulasisolutionssite/core/widgets/retained_task_edits.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';
import 'package:tulasisolutionssite/features/admin/tasks/task_deletion_dialog.dart';
import 'package:tulasisolutionssite/features/admin/tasks/sales_record_dialog.dart';
import 'package:tulasisolutionssite/features/admin/client_profile/assign_plan_dialog.dart';

const _feature = 'Content / Content: Artwork';
const _other = 'Software / Web: Website';

Plan _plan({String id = 'plan', String clientId = 'client'}) => Plan(
  id: id,
  clientId: clientId,
  type: PlanType.setup,
  name: 'Plan',
  price: 0,
  startDate: DateTime(2026, 10, 9),
  features: const [_feature, _other],
  tasks: const [
    ClientTask(
      id: 'art',
      category: 'Content / Content',
      title: 'Artwork',
      order: 0,
      source: ClientTaskSource.customIncluded,
    ),
    ClientTask(
      id: 'web',
      category: 'Software / Web',
      title: 'Website',
      order: 1,
      source: ClientTaskSource.customIncluded,
    ),
  ],
  taskWorkflow: const {
    _feature: {
      'assignedTo': 'staff',
      'status': 'assigned',
      'internalNotes': 'Original notes',
      'priority': 'normal',
    },
    _other: {'internalNotes': 'Original website notes'},
  },
);

Plan _notes(Plan plan, String text) => updateTaskManagementDetails(
  plan,
  _feature,
  dueAt: null,
  internalNotes: text,
);

class _RecoveryService implements FirestoreService {
  final Plan latest;
  final String clientNotes;
  final writes = <({Plan desired, Plan? previous})>[];
  int reads = 0;
  Completer<void>? deletionAck;
  final deletions = <String>[];
  _RecoveryService(this.latest, {this.clientNotes = ''});

  @override
  Future<Plan?> getPlanOnce(String id) async {
    reads++;
    return latest;
  }

  @override
  Future<Client?> getClient(String id, {bool serverOnly = false}) async =>
      Client(
        id: id,
        name: 'Customer',
        category: '',
        contactEmail: '',
        contactPhone: '',
        notes: clientNotes,
        stage: ClientStage.consult,
        createdDate: DateTime(2026, 10, 9),
      );

  @override
  Future<void> updatePlan(Plan plan, {Plan? previous}) async =>
      writes.add((desired: plan, previous: previous));

  @override
  Future<void> deletePlanTask(
    String planId,
    String feature,
    String confirmation,
  ) async {
    expect(confirmation, 'DELETE');
    deletions.add(feature);
    final ack = deletionAck;
    if (ack != null) await ack.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _showFailure(
  WidgetTester tester,
  _RecoveryService service, {
  bool personal = false,
  Plan? beforePlan,
  Plan? attemptedPlan,
  String? workflowKey = _feature,
  String? refreshClientId,
  Map<String, String> recoveryText = const {},
}) async {
  final before = beforePlan ?? _plan();
  final desired =
      attemptedPlan ??
      submitTaskForReview(
        _notes(before, 'My unsaved notes'),
        _feature,
        reviewer: 'admin',
      );
  final profile = AppUser(
    uid: personal ? 'staff' : 'admin',
    email: '',
    name: 'User',
    isAdmin: !personal,
    isStaff: true,
    panels: const ['myTasks'],
  );
  final staff = AppUser(uid: 'staff', email: '', name: 'Staff', isAdmin: false);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        currentUserProfileProvider.overrideWith((ref) async => profile),
        currentStaffIdsProvider.overrideWith((ref) => ['staff']),
        allUsersProvider.overrideWith((ref) => Stream.value([staff])),
        planTemplatesProvider.overrideWith((ref) => Stream.value([])),
        allPlansStreamProvider.overrideWith(
          (ref) => Stream.value([service.latest]),
        ),
        firestoreServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Column(
              children: [
                const TaskSaveFeedback(),
                TextButton(
                  onPressed: () => ref
                      .read(taskSavesProvider.notifier)
                      .submit(
                        desired: desired,
                        previous: before,
                        label: 'Artwork',
                        workflowKey: workflowKey,
                        refreshClientId: refreshClientId,
                        recoveryText: recoveryText,
                        lockedAssigneeId: personal ? 'staff' : null,
                        persist: () =>
                            Future.error(PlanSaveConflict('Notes changed.')),
                      ),
                  child: const Text('Attempt save'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Attempt save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'plan recovery opens latest values without applying retained text',
    (tester) async {
      final latest = _plan().copyWith(name: 'Latest server plan', price: 500);
      final service = _RecoveryService(latest);
      await _showFailure(
        tester,
        service,
        attemptedPlan: _plan().copyWith(name: 'My unsaved plan'),
        workflowKey: null,
      );
      await tester.tap(find.text('Reopen latest plan'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<AssignPlanDialog>(
        find.byType(AssignPlanDialog),
      );
      expect(dialog.existing, same(latest));
      expect(dialog.retainedEdits.values, contains('My unsaved plan'));
      expect(find.text('Latest server plan'), findsOneWidget);
      expect(find.text('My unsaved plan'), findsOneWidget);
      expect(service.writes, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reopen latest plan'), findsOneWidget);
    },
  );

  testWidgets(
    'sales recovery fetches latest task and customer and keeps attempted notes separate',
    (tester) async {
      const feature = 'Sales / Call: Call customer';
      final before = _plan().copyWith(
        features: const [feature],
        tasks: const [
          ClientTask(
            id: 'sale',
            category: 'Sales / Call',
            title: 'Call customer',
            order: 0,
            source: ClientTaskSource.customIncluded,
          ),
        ],
        taskWorkflow: const {
          feature: {
            'assignedTo': 'staff',
            'status': 'assigned',
            'internalNotes': 'Original sales notes',
          },
        },
      );
      Plan withNotes(String notes) => updateTaskManagementDetails(
        before,
        feature,
        dueAt: null,
        internalNotes: notes,
      );
      final latest = withNotes('Latest sales task notes');
      final service = _RecoveryService(
        latest,
        clientNotes: 'Latest customer notes',
      );
      await _showFailure(
        tester,
        service,
        beforePlan: before,
        attemptedPlan: withNotes('My unsaved sales task notes'),
        workflowKey: feature,
        refreshClientId: 'client',
        recoveryText: const {'Sales notes': 'My unsaved customer notes'},
      );
      await tester.tap(find.text('Reopen latest task'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<SalesRecordDialog>(
        find.byType(SalesRecordDialog),
      );
      expect(dialog.initialTask!.plan, same(latest));
      expect(dialog.client.notes, 'Latest customer notes');
      final notes = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Sales / follow-up notes',
      );
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Latest sales task notes\n\nLatest customer notes',
      );
      expect(find.text('My unsaved sales task notes'), findsOneWidget);
      expect(find.text('My unsaved customer notes'), findsOneWidget);
      expect(service.writes, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reopen latest task'), findsOneWidget);
    },
  );

  testWidgets('clipboard errors preserve retained text and show a failure', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard-denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RetainedTaskEdits(edits: {'Notes': 'My retained notes'}),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not copy retained text:'),
      findsOneWidget,
    );
    expect(find.text('Copied retained text.'), findsNothing);
    expect(find.text('My retained notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'a loading refresh with previous data cannot remove a confirmed save',
    () async {
      final reads = <Completer<List<Plan>>>[];
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          allPlansProvider.overrideWith((ref) {
            final read = Completer<List<Plan>>();
            reads.add(read);
            return read.future;
          }),
        ],
      );
      final listener = container.listen(visiblePlansOnceProvider, (_, _) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      reads.first.complete([_plan()]);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(taskSavesProvider.notifier);
      controller.submit(
        desired: _notes(_plan(), 'Confirmed notes'),
        previous: _plan(),
        label: 'Artwork',
        persist: () async {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(allPlansProvider).isLoading, isTrue);
      expect(controller.state['plan']!.phase, TaskSavePhase.confirmed);
      expect(
        container.read(visiblePlansOnceProvider).valueOrNull,
        hasLength(1),
      );
      reads.last.complete(PlanSnapshotList([], serverConfirmed: true));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isEmpty);
    },
  );

  test('a failed request cannot hide server-confirmed data', () async {
    final controller = TaskSaveController();
    addTearDown(controller.dispose);
    final before = _plan();
    final desired = _notes(before, 'Confirmed server notes');
    final ack = Completer<void>();
    controller.submit(
      desired: desired,
      previous: before,
      label: 'Artwork',
      persist: () => ack.future,
    );
    controller.reconcile(PlanSnapshotList([desired], serverConfirmed: true));
    ack.completeError(StateError('Acknowledgement unavailable'));
    await Future<void>.delayed(Duration.zero);
    expect(
      taskInternalNotes(controller.visiblePlans([desired]).single, _feature),
      'Confirmed server notes',
    );
  });

  test(
    'rollback of a renamed task retains another task and newer instructions',
    () {
      final before = _plan();
      final renamed = renamePlanTask(
        before,
        _feature,
        category: 'Content / Content',
        title: 'Renamed artwork',
      );
      final liveTask = renamed.tasks.first;
      final updatedTask = ClientTask(
        id: liveTask.id,
        category: liveTask.category,
        title: liveTask.title,
        instructions: 'Colleague instructions',
        order: liveTask.order,
        source: liveTask.source,
      );
      final live = renamed.copyWith(
        tasks: [updatedTask, renamed.tasks.last],
        price: 500,
      );
      final restored = overlayPlanChanges(
        live,
        renamed,
        before,
        rollback: true,
      );
      expect(restored.features, before.features);
      expect(restored.tasks.first.title, 'Artwork');
      expect(restored.tasks.first.instructions, 'Colleague instructions');
      expect(restored.price, 500);
      final newerRename = renamePlanTask(
        renamed,
        renamed.features.first,
        category: 'Content / Content',
        title: 'Colleague title',
      );
      final keepLatest = overlayPlanChanges(
        newerRename,
        renamed,
        before,
        rollback: true,
      );
      expect(keepLatest.features, newerRename.features);
      expect(keepLatest.tasks.first.title, 'Colleague title');
    },
  );

  testWidgets(
    'confirmed saves allow deletion, which still waits for server ack',
    (tester) async {
      final service = _RecoveryService(_plan())
        ..deletionAck = Completer<void>();
      await _showFailure(tester, service);
      final context = tester.element(find.byType(TaskSaveFeedback));
      final container = ProviderScope.containerOf(context);
      await container.read(currentUserProfileProvider.future);
      final controller = container.read(taskSavesProvider.notifier);
      controller.discard('plan');
      controller.submit(
        desired: _notes(_plan(), 'Saved notes'),
        previous: _plan(),
        label: 'Artwork',
        workflowKey: _feature,
        persist: () async {},
      );
      await tester.pumpAndSettle();
      expect(controller.state['plan']!.phase, TaskSavePhase.confirmed);
      final ref = tester
          .state<ConsumerState>(find.byType(TaskSaveFeedback))
          .ref;
      final deletion = confirmTaskDeletion(
        context,
        ref,
        planId: 'plan',
        feature: _feature,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Type DELETE to confirm'),
        'DELETE',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Deleting...'), findsOneWidget);
      expect(controller.state, hasLength(1));
      service.deletionAck!.complete();
      await tester.pumpAndSettle();
      expect(await deletion, isTrue);
      expect(service.deletions, [_feature]);
      expect(controller.state, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'failed save rolls back its fields, not newer unrelated task changes',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = _notes(
        before,
        'Failed notes',
      ).copyWith(completedFeatures: [_feature]);
      final live = desired.copyWith(
        price: 500,
        completedFeatures: [_feature, _other],
        taskWorkflow: {
          ...desired.taskWorkflow,
          _feature: {...desired.taskWorkflow[_feature]!, 'priority': 'urgent'},
          _other: {'internalNotes': 'New website notes'},
        },
      );
      final ack = Completer<void>();
      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: () => ack.future,
      );
      controller.reconcile(PlanSnapshotList([live], serverConfirmed: false));
      ack.completeError(StateError('Connection lost'));
      await Future<void>.delayed(Duration.zero);
      final visible = controller.visiblePlans([live]).single;
      expect(taskInternalNotes(visible, _feature), 'Original notes');
      expect(visible.price, 500);
      expect(visible.taskWorkflow[_feature]!['priority'], 'urgent');
      expect(taskInternalNotes(visible, _other), 'New website notes');
      expect(visible.completedFeatures, [_other]);
      expect(controller.state['plan']!.desired, same(desired));
    },
  );

  test(
    'failure does not overwrite a newer edit or recreate a removed task',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = _notes(before, 'Failed notes');
      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: () => Future.error(StateError('Connection lost')),
      );
      await Future<void>.delayed(Duration.zero);
      final newer = _notes(before, 'Latest colleague notes');
      expect(
        taskInternalNotes(controller.visiblePlans([newer]).single, _feature),
        'Latest colleague notes',
      );
      final removed = removePlanTask(newer, _feature);
      expect(controller.visiblePlans([removed]).single.features, [_other]);
      expect(
        controller
            .visiblePlans([removed])
            .single
            .taskWorkflow
            .containsKey(_feature),
        isFalse,
      );
    },
  );

  test(
    'cached absence cannot delete an overlay; complete server absence can',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = _notes(before, 'Saved notes');
      controller.reconcile([before]);
      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: () async {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state['plan']!.phase, TaskSavePhase.confirmed);
      expect(controller.hasUnsavedChanges, isFalse);
      controller.reconcile(PlanSnapshotList([], serverConfirmed: false));
      expect(controller.state, hasLength(1));
      expect(controller.visiblePlans([]), hasLength(1));
      controller.reconcile(PlanSnapshotList([], serverConfirmed: true));
      expect(controller.state, isEmpty);
      expect(controller.visiblePlans([]), isEmpty);
      expect(controller.visiblePlans([before]), isEmpty);
      controller.reconcile(PlanSnapshotList([before], serverConfirmed: true));
      expect(controller.visiblePlans([before]), hasLength(1));
    },
  );

  test(
    'client-scoped snapshots cannot delete a different client overlay',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan(clientId: 'second');
      controller.submit(
        desired: _notes(before, 'Saved notes'),
        previous: before,
        label: 'Artwork',
        persist: () async {},
      );
      await Future<void>.delayed(Duration.zero);
      controller.reconcile([
        _plan(id: 'another', clientId: 'first'),
      ], clientId: 'first');
      expect(controller.state, hasLength(1));
      controller.reconcile([], clientId: 'second');
      expect(controller.state, isEmpty);
    },
  );

  test(
    'cached matching data cannot clear saving; current server data wins after ack',
    () async {
      final controller = TaskSaveController();
      addTearDown(controller.dispose);
      final before = _plan();
      final desired = _notes(before, 'Saved notes');
      final ack = Completer<void>();
      controller.submit(
        desired: desired,
        previous: before,
        label: 'Artwork',
        persist: () => ack.future,
      );
      controller.reconcile(PlanSnapshotList([desired], serverConfirmed: false));
      ack.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state['plan']!.phase, TaskSavePhase.confirmed);
      final newest = _notes(desired, 'Later colleague edit');
      controller.reconcile(PlanSnapshotList([newest], serverConfirmed: true));
      expect(controller.state, isEmpty);
      expect(controller.visiblePlans([newest]).single, same(newest));
    },
  );

  test('conflicts and access errors cannot retry stale requests', () async {
    for (final error in [
      PlanSaveConflict('Task changed.'),
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    ]) {
      final controller = TaskSaveController();
      var calls = 0;
      controller.submit(
        desired: _notes(_plan(), 'Retained notes'),
        previous: _plan(),
        label: 'Artwork',
        persist: () {
          calls++;
          return Future.error(error);
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state['plan']!.canRetry, isFalse);
      expect(
        controller.state['plan']!.retainedText.values,
        contains('Retained notes'),
      );
      controller.retry('plan');
      expect(calls, 1);
      controller.dispose();
    }
  });

  test(
    'list errors leave confirmed state intact until a successful snapshot',
    () async {
      final stream = StreamController<List<Plan>>();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          allPlansStreamProvider.overrideWith((ref) => stream.stream),
        ],
      );
      final listener = container.listen(visiblePlansProvider, (_, _) {});
      addTearDown(() async {
        listener.close();
        container.dispose();
        await stream.close();
      });
      stream.add([_plan()]);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(taskSavesProvider.notifier);
      controller.submit(
        desired: _notes(_plan(), 'Saved notes'),
        previous: _plan(),
        label: 'Artwork',
        persist: () async {},
      );
      await Future<void>.delayed(Duration.zero);
      stream.addError(StateError('List unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state['plan']!.phase, TaskSavePhase.confirmed);
      stream.add(PlanSnapshotList([], serverConfirmed: false));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, hasLength(1));
      stream.add(PlanSnapshotList([], serverConfirmed: true));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isEmpty);
    },
  );

  test(
    'leave warning stays for failures, stops on discard/ack/disposal',
    () async {
      var registered = 0;
      var removed = 0;
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          pendingSaveWarningProvider.overrideWith(
            (ref) => () {
              registered++;
              return () => removed++;
            },
          ),
        ],
      );
      await container.read(authStateProvider.future);
      final controller = container.read(taskSavesProvider.notifier);
      controller.submit(
        desired: _plan(),
        previous: null,
        label: 'Artwork',
        persist: () => Future.error(StateError('Connection lost')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(registered, 1);
      expect(removed, 0);
      controller.discard('plan');
      expect(removed, 1);
      controller.submit(
        desired: _plan(),
        previous: null,
        label: 'Artwork',
        persist: () async {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(registered, 2);
      expect(removed, 2);
      final ack = Completer<void>();
      controller.submit(
        desired: _plan(),
        previous: null,
        label: 'Artwork',
        persist: () => ack.future,
      );
      expect(registered, 3);
      container.dispose();
      expect(removed, 3);
      ack.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  for (final personal in [false, true]) {
    testWidgets(
      'reopen fetches fresh data, retains text, does not replay approval: personal=$personal',
      (tester) async {
        final latest = _notes(
          _plan(),
          'Current server notes',
        ).copyWith(price: 500);
        final service = _RecoveryService(latest);
        await _showFailure(tester, service, personal: personal);
        expect(find.text('Retry save'), findsNothing);
        await tester.tap(find.text('Reopen latest task'));
        await tester.pumpAndSettle();
        expect(service.reads, 1);
        expect(find.byType(TaskWorkflowDialog), findsOneWidget);
        expect(find.text('My unsaved notes'), findsOneWidget);
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Internal project notes',
        );
        expect(
          tester.widget<TextField>(field).controller!.text,
          'Current server notes',
        );
        expect(find.text('Send for admin approval'), findsOneWidget);
        expect(service.writes, isEmpty);
        if (personal) expect(find.byTooltip('Delete task'), findsNothing);
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Reviewed recovered notes');
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(service.writes.single.previous, same(latest));
        expect(
          taskInternalNotes(service.writes.single.desired, _feature),
          'Reviewed recovered notes',
        );
        expect(service.writes.single.desired.price, 500);
        expect(
          taskStatus(service.writes.single.desired, _feature),
          TaskStatus.assigned,
        );
        expect(find.byType(TaskWorkflowDialog), findsNothing);
        expect(find.textContaining('Saved - updating list.'), findsNothing);
        expect(find.text('Refresh list'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('canceling recovery keeps the original text and failed request', (
    tester,
  ) async {
    final service = _RecoveryService(_notes(_plan(), 'Current server notes'));
    await _showFailure(tester, service);
    await tester.tap(find.text('Reopen latest task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View retained edits'));
    await tester.pumpAndSettle();
    expect(find.text('My unsaved notes'), findsOneWidget);
    expect(service.writes, isEmpty);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Reopen latest task'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sign-out confirmation can stay without losing edits', (
    tester,
  ) async {
    final service = _RecoveryService(_plan());
    await _showFailure(tester, service);
    final context = tester.element(find.byType(TaskSaveFeedback));
    final container = ProviderScope.containerOf(context);
    final ref = tester.state<ConsumerState>(find.byType(TaskSaveFeedback)).ref;
    final leave = confirmLeavingUnsavedTasks(context, ref);
    await tester.pumpAndSettle();
    expect(find.text('Unsaved task changes'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(await leave, isFalse);
    expect(
      container.read(taskSavesProvider)['plan']!.retainedText.values,
      contains('My unsaved notes'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
