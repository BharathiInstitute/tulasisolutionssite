import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/tasks/plan_changes.dart';
import 'package:tulasisolutionssite/core/widgets/task_tracking_widgets.dart';
import 'package:tulasisolutionssite/features/admin/tasks/sales_record_dialog.dart';
import 'package:tulasisolutionssite/features/admin/tasks/sales_tasks_tab.dart';

const _feature = 'Sales / Call: Discuss proposal';
final _admin = AppUser(uid: 'admin', email: '', name: 'Admin', isAdmin: true);

class _GatedSalesService extends FirestoreService {
  final release = Completer<void>();

  _GatedSalesService(FakeFirebaseFirestore db) : super(firestore: db);

  @override
  Future<Client> saveCustomerSalesUpdate({
    required Client client,
    required AppUser actor,
    required ClientStage stage,
    required String? progress,
    required DateTime? dueAt,
    required bool doNotContact,
    SalesTask? legacyTask,
    String? notes,
  }) async {
    await release.future;
    return super.saveCustomerSalesUpdate(
      client: client,
      actor: actor,
      stage: stage,
      progress: progress,
      dueAt: dueAt,
      doNotContact: doNotContact,
      legacyTask: legacyTask,
      notes: notes,
    );
  }
}

Client _client() => Client(
  id: 'customer',
  name: 'Customer',
  category: '',
  contactPhone: 'invalid-phone',
  contactEmail: '',
  stage: ClientStage.click,
  createdDate: DateTime(2026),
);

Plan _plan() => Plan(
  id: 'sales',
  clientId: 'customer',
  type: PlanType.setup,
  name: 'Sales Tasks',
  price: 0,
  startDate: DateTime(2026),
  features: const [_feature],
  taskWorkflow: {
    _feature: {
      'status': 'completed',
      'assignedTo': 'staff',
      'assignedToName': 'Staff',
      'dueAt': DateTime(2026, 10, 1).toIso8601String(),
      'internalNotes': 'Original notes',
    },
  },
);

void main() {
  testWidgets(
    'Confirmed sales edits reopen immediately and survive a delayed cached refresh',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final service = _GatedSalesService(db);
      final client = _client().copyWith(
        stage: ClientStage.consult,
        salesProgress: 'Considering',
        salesRecord: {
          'revision': 'original',
          'title': 'Considering',
          'action': 'Update',
          'status': 'assigned',
          'assignedTo': 'admin',
          'notes': 'Old notes',
        },
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final reads = <Completer<List<Client>>>[];
      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => _admin),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(service),
          allPlansStreamProvider.overrideWith((ref) => Stream.value([])),
          clientsListProvider.overrideWith((ref) {
            final read = Completer<List<Client>>();
            reads.add(read);
            return read.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: SalesTasksView())),
        ),
      );
      await tester.pump();
      reads.first.complete([client]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unscheduled (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Considering'));
      await tester.pumpAndSettle();
      final update = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Update',
      );
      await tester.tap(update);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ready to proceed').last);
      await tester.pumpAndSettle();
      final notes = find.byKey(const ValueKey('customer-sales-notes'));
      await tester.enterText(notes, 'Confirmed notes');
      await tester.tap(find.text('Save record'));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(container.read(confirmedSalesClientsProvider), isEmpty);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      await Navigator.of(tester.element(find.byType(AlertDialog))).maybePop();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      service.release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(reads.last.isCompleted, isFalse);
      expect(find.text('Progress: Ready to proceed'), findsOneWidget);
      await tester.tap(find.text('Ready to proceed'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Confirmed notes',
      );
      await tester.enterText(notes, 'Second saved edit');
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        container
            .read(confirmedSalesClientsProvider)[client.id]!
            .salesRecord['notes'],
        'Second saved edit',
      );
      reads.last.complete(ClientSnapshotList([client], serverConfirmed: false));
      await tester.pumpAndSettle();
      expect(find.text('Progress: Ready to proceed'), findsOneWidget);
      await tester.tap(find.text('Ready to proceed'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Second saved edit',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final stored = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      container.invalidate(clientsListProvider);
      container.read(clientsListProvider.future);
      await tester.pump();
      reads.last.complete(ClientSnapshotList([stored], serverConfirmed: true));
      await tester.pumpAndSettle();
      expect(container.read(confirmedSalesClientsProvider), isEmpty);
      expect(find.text('Progress: Ready to proceed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A rejected sales save keeps edits open and never publishes them as confirmed',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final service = _GatedSalesService(db);
      final client = _client().copyWith(
        salesRecord: {
          'revision': 'original',
          'title': 'Call',
          'action': 'Call',
          'status': 'assigned',
          'notes': 'Old notes',
        },
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => _admin),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(service),
          clientsListProvider.overrideWith((ref) async => [client]),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => SalesRecordDialog(
                      client: client,
                      plans: const [],
                      customerRecord: true,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final notes = find.byKey(const ValueKey('customer-sales-notes'));
      await tester.enterText(notes, 'Retained unsaved notes');
      await tester.tap(find.text('Save record'));
      await tester.pump();
      service.release.completeError(StateError('Connection unavailable'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('Could not save Sales record:'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Retained unsaved notes',
      );
      expect(container.read(confirmedSalesClientsProvider), isEmpty);
      expect(
        Client.fromFirestore(
          await db.collection('clients').doc(client.id).get(),
        ).salesRecord['notes'],
        'Old notes',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sales records stay visible while customer lists refresh and failures remain explicit',
    (tester) async {
      final reads = <Completer<List<Client>>>[];
      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => _admin),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          allPlansStreamProvider.overrideWith(
            (ref) => Stream.value([
              _plan().copyWith(
                taskWorkflow: {
                  _feature: {'status': 'assigned', 'assignedTo': 'admin'},
                },
              ),
            ]),
          ),
          clientsListProvider.overrideWith((ref) {
            final read = Completer<List<Client>>();
            reads.add(read);
            return read.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: SalesTasksView())),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      reads.first.complete([_client()]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unscheduled (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Discuss proposal'), findsOneWidget);
      final customerName = tester.widget<Text>(find.text('Customer'));
      expect(customerName.style!.fontWeight, FontWeight.bold);
      expect(customerName.style!.fontSize, greaterThanOrEqualTo(20));
      expect(
        find.text('Funnel stage: ${_client().stage.displayName}'),
        findsOneWidget,
      );
      expect(find.text('Current task to do'), findsOneWidget);
      expect(find.text('Progress: Not recorded'), findsOneWidget);
      expect(find.textContaining('All stages ('), findsNothing);
      for (final stage in chatFunnelStages) {
        expect(find.textContaining('${stage.displayName} ('), findsNothing);
      }
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('My tasks'), findsOneWidget);
      expect(find.text('Assignee'), findsOneWidget);
      expect(find.text('All active (1)'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Discuss proposal')).dx,
        greaterThan(tester.getTopLeft(find.text('Customer')).dx),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Discuss proposal')).dy,
        greaterThan(tester.getTopLeft(find.text('Customer')).dy),
      );
      expect(tester.takeException(), isNull);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      await tester.pumpAndSettle();
      container.invalidate(clientsListProvider);
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Discuss proposal'),
        findsOneWidget,
        reason:
            'Source: ${container.read(taskClientsProvider)}; '
            'visible: ${container.read(visibleTaskClientsProvider)}; '
            'plans: ${container.read(visiblePlansProvider)}',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      reads.last.complete([_client().copyWith(name: 'Updated customer')]);
      await tester.pumpAndSettle();
      expect(find.text('Updated customer'), findsOneWidget);
      expect(find.text('Refresh list'), findsNothing);
      container.invalidate(clientsListProvider);
      await tester.pump();
      await tester.pump();
      reads.last.completeError(StateError('Connection unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Sales tasks could not be loaded.'), findsOneWidget);
      expect(find.text('Retry sales tasks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Example preview isolates samples and disables persistent actions',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const SalesTasksExampleDialog(),
                  ),
                  child: const Text('Preview'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Sales Tasks - example preview'), findsOneWidget);
      expect(find.text('Call about monthly plan'), findsOneWidget);
      expect(find.text('Create sales task'), findsNothing);
      await tester.tap(find.text('Call about monthly plan'));
      await tester.pumpAndSettle();
      expect(find.text('Sales record'), findsOneWidget);
      expect(find.text('Customer activity log'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save record'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Call customer'),
            )
            .onPressed,
        isNull,
      );
      expect(find.byTooltip('Delete task'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      for (final label in [
        'Upcoming (1)',
        'Unscheduled (1)',
        'Completed (1)',
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(find.text('Introduction call'), findsOneWidget);
      await tester.tap(find.byTooltip('Close example preview'));
      await tester.pumpAndSettle();
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Example Learning Centre'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Follow-up saving preserves concurrent task changes and rolls back conflicts',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      final client = _client();
      final original = _plan();
      final nextTask = ClientTask(
        id: 'next-task',
        category: 'Sales / Meeting',
        title: 'Proposal meeting',
        order: 0,
        source: ClientTaskSource.customIncluded,
        addedReason: 'Next step',
      );
      final desired = updateSalesRecordTask(
        updateTaskAssignment(
          original.copyWith(
            features: [...original.features, nextTask.feature],
            tasks: [nextTask],
          ),
          nextTask.feature,
          assignedTo: 'admin',
          assignedToName: 'Admin',
          priority: 'normal',
        ),
        nextTask.feature,
        '',
        DateTime(2026, 10, 12),
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final concurrent = original.copyWith(
        taskWorkflow: {
          ...original.taskWorkflow,
          _feature: {
            ...original.taskWorkflow[_feature]!,
            'assignedTo': 'new-staff',
          },
        },
      );
      await db
          .collection('plans')
          .doc(original.id)
          .set(concurrent.toFirestore());
      Future<void> save(AppUser actor) => service.saveSalesRecord(
        client: client,
        plan: desired,
        feature: _feature,
        addTask: false,
        notes: 'Updated notes',
        dueAt: taskDueAt(original, _feature),
        stage: client.stage,
        contacts: const [
          {'id': 'contact', 'method': 'Call', 'outcome': 'No answer'},
        ],
        editCustomer: true,
        editTask: true,
        actor: actor,
        nextFeature: nextTask.feature,
      );
      await expectLater(
        save(
          AppUser(
            uid: 'staff',
            email: '',
            name: 'Staff',
            isAdmin: false,
            isStaff: true,
            panels: const ['myTasks'],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        (await db.collection('plans').doc(original.id).get()).data(),
        concurrent.toFirestore(),
      );
      await save(_admin);
      final saved = Plan.fromFirestore(
        await db.collection('plans').doc(original.id).get(),
      );
      expect(taskAssigneeId(saved, _feature), 'new-staff');
      expect(taskStatus(saved, _feature), TaskStatus.completed);
      expect(
        saved.tasks.singleWhere((task) => task.feature == nextTask.feature).id,
        nextTask.id,
      );
      final before = (await db.collection('plans').doc(original.id).get())
          .data();
      final customerBefore =
          (await db.collection('clients').doc(client.id).get()).data();
      await expectLater(save(_admin), throwsA(isA<PlanSaveConflict>()));
      expect(
        (await db.collection('plans').doc(original.id).get()).data(),
        before,
      );
      expect(
        (await db.collection('clients').doc(client.id).get()).data(),
        customerBefore,
      );
    },
  );

  testWidgets('Sales due labels use exact local dates and overdue thresholds', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 10, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              for (final due in [
                null,
                now.subtract(const Duration(minutes: 1)),
                DateTime(2026, 10, 9, 23),
                DateTime(2026, 10, 8, 23),
                now,
                DateTime(2026, 10, 11),
                DateTime.utc(2026, 10, 12, 12),
              ])
                Text(salesTaskDueLabel(context, due, now)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Unscheduled'), findsOneWidget);
    expect(find.textContaining('Overdue - today,'), findsOneWidget);
    expect(find.text('Overdue by 1 day'), findsOneWidget);
    expect(find.text('Overdue by 2 days'), findsOneWidget);
    expect(find.textContaining('Today,'), findsOneWidget);
    expect(find.textContaining('Tomorrow,'), findsOneWidget);
    expect(find.textContaining('Oct'), findsOneWidget);
  });

  testWidgets('Sales admin filters count only selected assignees', (
    tester,
  ) async {
    final plan = _plan().copyWith(
      features: const [_feature, 'Sales / WhatsApp: Send pricing'],
      taskWorkflow: {
        _feature: {
          'assignedTo': 'staff',
          'assignedToName': 'Staff',
          'dueAt': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        },
        'Sales / WhatsApp: Send pricing': {
          'assignedTo': 'admin',
          'assignedToName': 'Admin',
        },
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => _admin),
          currentStaffIdsProvider.overrideWithValue(['admin']),
          visiblePlansProvider.overrideWith(
            (ref) => AsyncData([
              plan.copyWith(features: [_feature]),
              plan.copyWith(
                id: 'second-sales',
                clientId: 'second',
                features: ['Sales / WhatsApp: Send pricing'],
              ),
            ]),
          ),
          taskClientsProvider.overrideWith(
            (ref) async => [_client(), _client().copyWith(id: 'second')],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SalesTasksView())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today & Overdue (1)'), findsOneWidget);
    expect(find.text('Overdue by 2 days'), findsNothing);
    expect(find.text('Due: Overdue by 2 days'), findsOneWidget);
    await tester.tap(find.text('My tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Today & Overdue (0)'), findsOneWidget);
    expect(find.text('All active (1)'), findsOneWidget);
    await tester.tap(find.text('Unscheduled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Send pricing'), findsOneWidget);
    expect(find.textContaining('Assignee:'), findsNothing);
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff').last);
    await tester.pumpAndSettle();
    expect(find.text('All active (1)'), findsOneWidget);
    expect(find.text('Unscheduled (0)'), findsOneWidget);
    await tester.tap(find.text('Today & Overdue (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Discuss proposal'), findsOneWidget);
    expect(find.text('Send pricing'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Next follow-up preserves completed task and saves contact outcome',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final client = _client();
      final plan = _plan();
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      await db.collection('plans').doc(plan.id).set(plan.toFirestore());
      final service = FirestoreService(firestore: db);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) async => _admin),
            currentStaffIdsProvider.overrideWithValue(['admin']),
            firestoreServiceProvider.overrideWithValue(service),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            clientsListProvider.overrideWith((ref) async => [client]),
            visiblePlansProvider.overrideWith((ref) => AsyncData([plan])),
            taskClientsProvider.overrideWith((ref) async => [client]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => SalesRecordDialog(
                      client: client,
                      plans: [plan],
                      initialTask: (plan: plan, feature: _feature),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sales task'), findsOneWidget);
      expect(find.text('Call customer'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
      await tester.tap(find.text('Call customer'));
      await tester.pumpAndSettle();
      expect(
        find.text('This customer has no usable phone number.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byTooltip('Log contact'));
      await tester.tap(find.byTooltip('Log contact'));
      await tester.pumpAndSettle();
      final outcome = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Outcome',
      );
      await tester.ensureVisible(outcome);
      await tester.tap(outcome);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meeting scheduled').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Schedule next follow-up'));
      await tester.tap(find.text('Schedule next follow-up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(
        find.text('A next follow-up title and date/time are required.'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('sales-next-title')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('sales-next-title')),
        'Meet about proposal',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('sales-next-reminder')),
      );
      await tester.tap(find.byKey(const ValueKey('sales-next-reminder')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final saved = Plan.fromFirestore(
        await db.collection('plans').doc(plan.id).get(),
      );
      expect(saved.features, hasLength(2));
      for (final field in [
        'status',
        'assignedTo',
        'assignedToName',
        'dueAt',
        'internalNotes',
      ]) {
        expect(
          saved.taskWorkflow[_feature]![field],
          plan.taskWorkflow[_feature]![field],
        );
      }
      final next = saved.features.last;
      expect(next, 'Sales / Call: Meet about proposal');
      expect(taskStatus(saved, next), TaskStatus.assigned);
      expect(taskAssigneeId(saved, next), 'admin');
      expect(taskDueAt(saved, next), isNotNull);
      final customer = (await db.collection('clients').doc(client.id).get())
          .data()!;
      expect(customer['stage'], client.toFirestore()['stage']);
      final contacts = customer['salesContacts'] as List;
      expect(contacts.single['outcome'], 'Meeting scheduled');
      expect(tester.takeException(), isNull);
    },
  );
}
