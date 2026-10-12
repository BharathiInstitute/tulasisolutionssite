import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';
import 'package:tulasisolutionssite/features/admin/tasks/sales_record_dialog.dart';

const _feature = 'Content / Content: 2 reels';
const _other = 'Software / Web: Website';

Plan _plan() => Plan(
  id: 'plan',
  clientId: 'client',
  type: PlanType.setup,
  name: 'Paid plan',
  price: 500,
  startDate: DateTime(2026, 10, 9),
  features: const [_feature, _other],
  tasks: const [
    ClientTask(
      id: 'reels',
      category: 'Content / Content',
      title: '2 reels',
      instructions: '',
      order: 0,
      source: ClientTaskSource.customIncluded,
    ),
    ClientTask(
      id: 'web',
      category: 'Software / Web',
      title: 'Website',
      instructions: '',
      order: 1,
      source: ClientTaskSource.customIncluded,
    ),
  ],
  completedFeatures: const [_feature],
  featureProgress: const {_feature: 50, '$_feature#1': 100, _other: 30},
  taskWorkflow: const {
    _feature: {'assignedTo': 'staff'},
    '$_feature#1': {
      'status': 'completed',
      'cycles': [
        {'cycle': 1, 'status': 'completed'},
      ],
    },
    '$_feature#2': {
      'cycles': [
        {'cycle': 1, 'draftLink': 'draft'},
      ],
    },
    _other: {'assignedTo': 'other-staff', 'internalNotes': 'Keep'},
  },
);

class _DeleteService implements FirestoreService {
  final requests = <List<String>>[];
  bool fail = false;

  @override
  Future<void> deletePlanTask(
    String planId,
    String feature,
    String confirmation,
  ) async {
    if (fail) throw StateError('Connection unavailable');
    requests.add([planId, feature, confirmation]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _showRow(
  WidgetTester tester,
  _DeleteService service, {
  bool admin = true,
  bool personal = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProfileProvider.overrideWith(
          (ref) async => AppUser(
            uid: 'user',
            email: '',
            name: 'User',
            isAdmin: admin,
            isStaff: true,
            panels: const ['tasks', 'myTasks'],
          ),
        ),
        allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
        currentStaffIdsProvider.overrideWith((ref) => ['user']),
        firestoreServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TaskRow(
            task: TaskItem(
              rawFeature: _feature,
              plan: _plan(),
              unitIndex: 1,
              unitTotal: 2,
            ),
            category: 'Content',
            clientName: 'Client',
            lockedAssigneeId: personal ? 'user' : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _confirmationField() => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is AlertDialog &&
        widget.title is Text &&
        (widget.title as Text).data == 'Delete task?',
  ),
  matching: find.byType(TextField),
);

Future<void> _openPreview(WidgetTester tester) async {
  expect(find.byTooltip('Delete task'), findsNothing);
  await tester.tap(find.byType(ListTile));
  await tester.pumpAndSettle();
  expect(find.text('Task Details'), findsOneWidget);
}

void main() {
  for (final admin in [false, true]) {
    testWidgets('personal task preview hides every delete icon: admin=$admin', (
      tester,
    ) async {
      final service = _DeleteService();
      await _showRow(tester, service, admin: admin, personal: true);
      await _openPreview(tester);
      expect(find.byTooltip('Delete task'), findsNothing);
      expect(find.byTooltip('Delete draft'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(service.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final personal in [false, true]) {
    testWidgets(
      'sales preview deletion respects staff view: personal=$personal',
      (tester) async {
        const feature = 'Sales / Call: Follow up';
        final service = _DeleteService();
        final plan = _plan().copyWith(features: [feature]);
        final client = Client(
          id: 'client',
          name: 'Client',
          category: '',
          contactEmail: '',
          contactPhone: '',
          stage: ClientStage.click,
          createdDate: DateTime(2026),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProfileProvider.overrideWith(
                (ref) async => AppUser(
                  uid: 'admin',
                  email: '',
                  name: 'Admin',
                  isAdmin: true,
                ),
              ),
              currentStaffIdsProvider.overrideWith((ref) => ['admin']),
              firestoreServiceProvider.overrideWithValue(service),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SalesRecordDialog(
                        client: client,
                        plans: [plan],
                        initialTask: (plan: plan, feature: feature),
                        allowDeletion: !personal,
                      ),
                    ),
                    child: const Text('Open sales preview'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open sales preview'));
        await tester.pumpAndSettle();
        if (personal) {
          expect(find.byTooltip('Delete task'), findsNothing);
          expect(find.byIcon(Icons.delete_outline), findsNothing);
          expect(service.requests, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        await tester.tap(find.byTooltip('Delete task'));
        await tester.pumpAndSettle();
        await tester.enterText(_confirmationField(), 'DELETE');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(service.requests, [
          ['plan', feature, 'DELETE'],
        ]);
        expect(find.byType(SalesRecordDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'removing a task removes all unit data but preserves its plan and other tasks',
    () {
      final updated = removePlanTask(_plan(), _feature);
      expect(updated.features, [_other]);
      expect(updated.tasks.single.id, 'web');
      expect(updated.completedFeatures, isEmpty);
      expect(updated.featureProgress, {_other: 30});
      expect(updated.taskWorkflow, {
        _other: {'assignedTo': 'other-staff', 'internalNotes': 'Keep'},
      });
      expect(updated.price, 500);
      expect(updated.clientId, 'client');
      expect(updated.name, 'Paid plan');
      expect(() => removePlanTask(updated, _feature), throwsStateError);
    },
  );

  test(
    'deletion transaction preserves live updates and requires exact confirmation',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      final doc = db.collection('plans').doc('plan');
      await doc.set(_plan().toFirestore());
      await doc.update({
        'taskWorkflow.$_other.internalNotes': 'Concurrent edit',
      });
      for (final confirmation in ['', 'delete', 'DELETE ']) {
        await expectLater(
          service.deletePlanTask('plan', _feature, confirmation),
          throwsArgumentError,
        );
      }
      expect((await doc.get()).data()!['features'], [_feature, _other]);
      await service.deletePlanTask('plan', _feature, 'DELETE');
      final saved = Plan.fromFirestore(await doc.get());
      expect(saved.features, [_other]);
      expect(saved.taskWorkflow[_other]?['internalNotes'], 'Concurrent edit');
      expect(saved.price, 500);
      await expectLater(
        service.deletePlanTask('plan', _feature, 'DELETE'),
        throwsStateError,
      );
      await expectLater(
        service.deletePlanTask('missing', _feature, 'DELETE'),
        throwsStateError,
      );
    },
  );

  testWidgets('non-admin task managers cannot see the delete button', (
    tester,
  ) async {
    final service = _DeleteService();
    await _showRow(tester, service, admin: false);
    await _openPreview(tester);
    expect(find.byTooltip('Delete task'), findsNothing);
    expect(service.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('admin must type DELETE and can cancel without deleting', (
    tester,
  ) async {
    final service = _DeleteService();
    await _showRow(tester, service);
    await _openPreview(tester);
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    final delete = find.widgetWithText(FilledButton, 'Delete');
    expect(tester.widget<FilledButton>(delete).onPressed, isNull);
    for (final text in ['delete', 'DELETE ']) {
      await tester.enterText(_confirmationField(), text);
      await tester.pump();
      expect(tester.widget<FilledButton>(delete).onPressed, isNull);
    }
    await tester.enterText(_confirmationField(), 'DELETE');
    await tester.pump();
    expect(tester.widget<FilledButton>(delete).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(service.requests, isEmpty);
    expect(find.text('Task Details'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    await tester.enterText(_confirmationField(), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(service.requests, [
      ['plan', _feature, 'DELETE'],
    ]);
    expect(find.text('Delete task?'), findsNothing);
    expect(find.text('Task Details'), findsNothing);
    expect(find.text('Task deleted.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deletion errors stay visible and allow retry on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = _DeleteService()..fail = true;
    await _showRow(tester, service);
    await _openPreview(tester);
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    await tester.enterText(_confirmationField(), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not delete task:'), findsOneWidget);
    expect(service.requests, isEmpty);
    service.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(service.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
