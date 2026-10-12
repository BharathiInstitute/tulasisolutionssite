import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/plan_changes.dart';
import 'package:tulasisolutionssite/features/admin/tasks/unlinked_plan_repair.dart';

Plan _plan() => Plan(
  id: 'plan',
  clientId: 'missing',
  type: PlanType.setup,
  name: 'Old tasks',
  price: 500,
  startDate: DateTime(2026, 1, 1),
  features: const ['Content: Artwork', 'Sales: Follow-up'],
  completedFeatures: const ['Sales: Follow-up'],
  featureProgress: const {'Content: Artwork': 40},
  taskWorkflow: const {
    'Content: Artwork': {
      'assignedTo': 'staff',
      'internalNotes': 'Keep these notes',
      'cycles': [
        {'cycle': 3, 'status': 'draftCycle', 'draftLinks': 'Keep this link'},
      ],
    },
    'Sales: Follow-up': {
      'status': 'completed',
      'isArchived': true,
      'completedAt': '2026-01-02T12:00:00Z',
    },
  },
);

Client _client() => Client(
  id: 'client',
  name: 'Correct customer',
  category: '',
  contactEmail: '',
  contactPhone: '',
  stage: ClientStage.client,
  createdDate: DateTime(2026, 1, 1),
);

void main() {
  for (final destination in ['client', '__internal_practice__']) {
    test(
      'relink whole plan preserves every field except clientId: $destination',
      () async {
        final db = FakeFirebaseFirestore();
        final before = _plan().toFirestore();
        await db.collection('plans').doc('plan').set(before);
        await db
            .collection('clients')
            .doc('client')
            .set(_client().toFirestore());
        final service = FirestoreService(firestore: db);
        // A colleague's note edit must survive the repair.
        await db.collection('plans').doc('plan').update({
          'name': 'Colleague renamed plan',
        });
        final fresh = (await db.collection('plans').doc('plan').get()).data()!;
        await service.relinkUnlinkedPlan(
          'plan',
          previousClientId: 'missing',
          clientId: destination,
          expectedTaskCount: 2,
        );
        final after = (await db.collection('plans').doc('plan').get()).data()!;
        expect(after, {...fresh, 'clientId': destination});
      },
    );
  }

  for (final conflict in [
    'existing original',
    'missing destination',
    'changed link',
    'changed count',
  ]) {
    test('repair rejects $conflict without modifying plan', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('plans').doc('plan').set(_plan().toFirestore());
      if (conflict != 'missing destination') {
        await db
            .collection('clients')
            .doc('client')
            .set(_client().toFirestore());
      }
      if (conflict == 'existing original') {
        await db
            .collection('clients')
            .doc('missing')
            .set(_client().toFirestore());
      }
      if (conflict == 'changed link') {
        await db.collection('plans').doc('plan').update({
          'clientId': 'another',
        });
      }
      if (conflict == 'changed count') {
        await db.collection('plans').doc('plan').update({
          'features': ['Content: Artwork'],
        });
      }
      final before = (await db.collection('plans').doc('plan').get()).data();
      await expectLater(
        FirestoreService(firestore: db).relinkUnlinkedPlan(
          'plan',
          previousClientId: 'missing',
          clientId: 'client',
          expectedTaskCount: 2,
        ),
        throwsA(isA<PlanSaveConflict>()),
      );
      expect((await db.collection('plans').doc('plan').get()).data(), before);
    });
  }

  testWidgets(
    'admin preview offers whole-plan confirmation; cancel changes nothing',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('plans').doc('plan').set(_plan().toFirestore());
      await db.collection('clients').doc('client').set(_client().toFirestore());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            currentUserProfileProvider.overrideWith(
              (ref) async => AppUser(
                uid: 'admin',
                email: '',
                name: 'Admin',
                isAdmin: true,
              ),
            ),
            taskClientsProvider.overrideWith((ref) async => [_client()]),
            firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: db),
            ),
            allPlansStreamProvider.overrideWith(
              (ref) => Stream.value([_plan()]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        AlertDialog(content: UnlinkedPlanRepair(plan: _plan())),
                  ),
                  child: const Text('Open preview'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();
      expect(find.text('Saved client ID: missing'), findsNothing);
      await tester.tap(find.text('Client link details'));
      await tester.pumpAndSettle();
      expect(find.text('Saved client ID: missing'), findsOneWidget);
      await tester.tap(find.text('Link to client'));
      await tester.pumpAndSettle();
      expect(find.textContaining('all 2 tasks'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm link'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('plans').doc('plan').get()).data()!['clientId'],
        'missing',
      );
      await tester.tap(find.text('Link to client'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct customer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm link'));
      await tester.pumpAndSettle();
      expect((await db.collection('plans').doc('plan').get()).data(), {
        ..._plan().toFirestore(),
        'clientId': 'client',
      });
      expect(find.text('Link the whole plan?'), findsNothing);
      expect(find.text('Link to client'), findsNothing);
      expect(
        find.text('Plan linked. All task history was preserved.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('staff cannot see link repair or technical IDs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) async =>
                AppUser(uid: 'staff', email: '', name: 'Staff', isAdmin: false),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: UnlinkedPlanRepair(plan: _plan())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Link to client'), findsNothing);
    expect(find.text('Client link details'), findsNothing);
  });
}
