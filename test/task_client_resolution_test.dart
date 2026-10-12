import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/features/admin/tasks/my_assigned_tasks_screen.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';

const _phone = '919876543210';

class _AuthService extends Fake implements FirebaseAuthService {
  @override
  User? getCurrentUser() => null;
}

Client _client(String id, String name) => Client(
  id: id,
  name: name,
  category: '',
  contactEmail: '',
  contactPhone: _phone,
  stage: ClientStage.client,
  createdDate: DateTime(2026, 10, 9),
);

Plan _plan(String id, String clientId, {bool completed = false}) => Plan(
  id: id,
  clientId: clientId,
  type: PlanType.setup,
  name: 'Tasks',
  price: 0,
  startDate: DateTime(2026, 10, 9),
  features: ['$id work'],
  taskWorkflow: {
    '$id work': {
      'assignedTo': 'staff',
      'status': completed ? 'completed' : 'assigned',
    },
  },
);

class _Service extends FirestoreService {
  final lookups = <String>[];
  bool failLookup = false;

  _Service(FakeFirebaseFirestore firestore) : super(firestore: firestore);

  @override
  Future<Client?> getClient(String id, {bool serverOnly = false}) {
    expect(serverOnly, isTrue);
    lookups.add(id);
    if (failLookup) throw StateError('Client lookup connection failed');
    return super.getClient(id, serverOnly: serverOnly);
  }
}

Future<_Service> _service() async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('clients')
      .doc(_phone)
      .set(_client(_phone, 'Canonical customer').toFirestore());
  await db
      .collection('clients')
      .doc('legacy')
      .set(_client('legacy', 'Original linked customer').toFirestore());
  return _Service(db);
}

void main() {
  testWidgets(
    'My Tasks due filters combine with categories and can be cleared',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final router = GoRouter(
        initialLocation: '/admin/my-tasks',
        routes: [
          GoRoute(
            path: '/admin/my-tasks',
            builder: (_, _) => const MyAssignedTasksScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final dueDates = {
        'Content: Due this evening': tomorrow.subtract(
          const Duration(minutes: 1),
        ),
        'Content: Overdue': DateTime(now.year, now.month, now.day - 1),
        'Software: Due tomorrow': tomorrow,
        'Sales: Sales follow-up': tomorrow,
        'Sales / Call: Sales call': tomorrow,
      };
      final features = [
        ...dueDates.keys,
        'Content: No date',
        'Content: Archived',
        'Content: Completed',
        'Content: Another person',
        'Sales: Archived sales follow-up',
      ];
      final plan = Plan(
        id: 'my-filters',
        clientId: 'linked',
        type: PlanType.setup,
        name: 'Tasks',
        price: 0,
        startDate: now,
        features: features,
        taskWorkflow: {
          for (final feature in features)
            feature: {
              'assignedTo': feature == 'Content: Another person'
                  ? 'someone-else'
                  : 'staff',
              if (dueDates.containsKey(feature))
                'dueAt': dueDates[feature]!.toIso8601String(),
              if (feature == 'Content: Archived' ||
                  feature == 'Sales: Archived sales follow-up')
                'isArchived': true,
              'status': feature == 'Content: Completed'
                  ? 'completed'
                  : 'assigned',
            },
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: FakeFirebaseFirestore()),
            ),
            firebaseAuthServiceProvider.overrideWithValue(_AuthService()),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            currentStaffIdsProvider.overrideWithValue(['staff']),
            currentUserProfileProvider.overrideWith(
              (ref) async => AppUser(
                uid: 'staff',
                email: '',
                name: 'Staff',
                isAdmin: false,
                isStaff: true,
              ),
            ),
            clientsListProvider.overrideWith(
              (ref) async => [_client('linked', 'Linked customer')],
            ),
            taskClientsProvider.overrideWith(
              (ref) async => [_client('linked', 'Linked customer')],
            ),
            allPlansStreamProvider.overrideWith((ref) => Stream.value([plan])),
            allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Today & Overdue (2)'), findsOneWidget);
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Unscheduled (1)'), findsOneWidget);
      final categoryChip = find.widgetWithText(
        FilterChip,
        'Content / Content (3)',
      );
      for (final label in [
        'Software / Web (1)',
        'All (4)',
        'Today & Overdue (2)',
        'Upcoming (1)',
        'Unscheduled (1)',
      ]) {
        expect(
          tester.getTopLeft(find.widgetWithText(FilterChip, label)).dy,
          tester.getTopLeft(categoryChip).dy,
          reason:
              '$label should share the category row: '
              '${tester.getRect(find.widgetWithText(FilterChip, label))}; '
              'category: ${tester.getRect(categoryChip)}',
        );
      }
      expect(find.text('Archived (1)'), findsOneWidget);
      expect(find.text('Sales (2)'), findsNothing);
      expect(find.text('Sales follow-up'), findsNothing);
      expect(find.text('Sales call'), findsNothing);
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Archived sales follow-up'), findsNothing);
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsNothing);
      expect(find.text('Another person'), findsNothing);

      await tester.tap(find.text('Today & Overdue (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Due this evening'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Due tomorrow'), findsNothing);
      expect(find.text('No date'), findsNothing);
      await tester.tap(find.text('Upcoming (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Due tomorrow'), findsOneWidget);
      expect(find.text('Due this evening'), findsNothing);
      await tester.tap(find.text('Upcoming (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Due this evening'), findsOneWidget);
      expect(find.text('No date'), findsOneWidget);
      await tester.tap(find.text('Unscheduled (1)'));
      await tester.pumpAndSettle();
      expect(find.text('No date'), findsOneWidget);
      expect(find.text('Due this evening'), findsNothing);

      await tester.tap(find.text('Software / Web (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Today & Overdue (0)'), findsOneWidget);
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Unscheduled (0)'), findsOneWidget);
      expect(find.text('No tasks match the selected filters'), findsOneWidget);
      await tester.tap(find.text('Upcoming (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Due tomorrow'), findsOneWidget);
      await tester.tap(find.text('All (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Due tomorrow'), findsOneWidget);
      expect(find.text('Due this evening'), findsNothing);
      await tester.tap(find.text('Content / Content (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming (0)'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Due this evening'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Due tomorrow'), findsOneWidget);
      expect(find.text('No date'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);

      tester.view.physicalSize = const Size(390, 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getTopLeft(find.widgetWithText(FilterChip, 'Unscheduled (1)'))
            .dy,
        greaterThan(tester.getTopLeft(categoryChip).dy),
      );
      await tester.tap(find.text('Unscheduled (1)'));
      await tester.pumpAndSettle();
      expect(find.text('No date'), findsOneWidget);
      expect(find.text('Due this evening'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final emptyCase in ['sales-only', 'no-plans', 'no-staff']) {
    testWidgets('My Tasks keeps zero-count filters visible: $emptyCase', (
      tester,
    ) async {
      final plan = _plan('sales-only', 'linked').copyWith(
        features: ['Sales: Only sales task'],
        taskWorkflow: {
          'Sales: Only sales task': {
            'assignedTo': 'staff',
            'status': 'assigned',
          },
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: FakeFirebaseFirestore()),
            ),
            firebaseAuthServiceProvider.overrideWithValue(_AuthService()),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            currentStaffIdsProvider.overrideWithValue(
              emptyCase == 'no-staff' ? [] : ['staff'],
            ),
            currentUserProfileProvider.overrideWith(
              (ref) async => AppUser(
                uid: 'staff',
                email: '',
                name: 'Staff',
                isAdmin: false,
                isStaff: true,
              ),
            ),
            taskClientsProvider.overrideWith((ref) async => <Client>[]),
            allPlansStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(emptyCase == 'no-plans' ? <Plan>[] : [plan]),
            ),
            allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
          ],
          child: const MaterialApp(home: MyAssignedTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No tasks assigned yet'), findsOneWidget);
      expect(find.text('Only sales task'), findsNothing);
      for (final label in [
        'All (0)',
        'Today & Overdue (0)',
        'Upcoming (0)',
        'Unscheduled (0)',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(FilterChip), findsNWidgets(4));
      expect(find.text('Archived (0)'), findsOneWidget);
      await tester.tap(find.text('Upcoming (0)'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Upcoming (0)'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('All (0)'), findsOneWidget);
      expect(find.text('No tasks assigned yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Assign Tasks quick filters combine and clear without including archived tasks',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final service = FirestoreService(firestore: FakeFirebaseFirestore());
      final router = GoRouter(
        initialLocation: '/admin/tasks',
        routes: [
          GoRoute(path: '/admin/tasks', builder: (_, _) => const TasksScreen()),
        ],
      );
      addTearDown(router.dispose);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final plan = Plan(
        id: 'filters',
        clientId: 'linked',
        type: PlanType.setup,
        name: 'Tasks',
        price: 0,
        startDate: now,
        features: const [
          'Content: Due today',
          'Content: Due tomorrow',
          'Content: No date',
          'Content: Overdue unassigned',
          'Content: Archived',
          'Content: Completed',
        ],
        taskWorkflow: {
          'Content: Due today': {
            'assignedTo': 'staff',
            'dueAt': today.toIso8601String(),
          },
          'Content: Due tomorrow': {
            'assignedTo': 'staff',
            'dueAt': tomorrow.toIso8601String(),
          },
          'Content: Overdue unassigned': {
            'dueAt': today.subtract(const Duration(days: 1)).toIso8601String(),
          },
          'Content: Archived': {'isArchived': true},
          'Content: Completed': {'status': 'completed'},
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreServiceProvider.overrideWithValue(service),
            firebaseAuthServiceProvider.overrideWithValue(_AuthService()),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            currentUserProfileProvider.overrideWith(
              (ref) async => AppUser(
                uid: 'admin',
                email: '',
                name: 'Admin',
                isAdmin: true,
              ),
            ),
            clientsListProvider.overrideWith(
              (ref) async => [_client('linked', 'Linked customer')],
            ),
            taskClientsProvider.overrideWith(
              (ref) async => [_client('linked', 'Linked customer')],
            ),
            allPlansStreamProvider.overrideWith((ref) => Stream.value([plan])),
            allUsersProvider.overrideWith(
              (ref) => Stream.value([
                AppUser(
                  uid: 'staff',
                  email: '',
                  name: 'Assigned person',
                  isAdmin: false,
                ),
              ]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4 tasks shown'), findsOneWidget);
      expect(find.text('Today & Overdue (2)'), findsOneWidget);
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Unscheduled (1)'), findsOneWidget);
      expect(find.text('Unassigned (2)'), findsOneWidget);
      final summaryTitle = find.text('Assign Tasks  4');
      final summaryCard = find.ancestor(
        of: summaryTitle,
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: summaryCard, matching: find.byType(FilterChip)),
        findsNWidgets(4),
      );
      expect(
        tester.getTopLeft(find.text('Today & Overdue (2)')).dx,
        greaterThan(tester.getTopRight(summaryTitle).dx),
      );
      expect(
        tester.getRect(find.text('Today & Overdue (2)')).top,
        lessThan(tester.getRect(summaryTitle).bottom),
      );
      tester.view.physicalSize = const Size(390, 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Unassigned (2)')).bottom,
        lessThan(tester.getRect(summaryCard).bottom),
      );
      expect(
        tester.getRect(summaryCard).bottom,
        lessThan(tester.getRect(find.text('Search tasks')).top),
      );
      tester.view.physicalSize = const Size(1800, 1000);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today & Overdue (2)'));
      await tester.pumpAndSettle();
      expect(find.text('2 tasks shown'), findsOneWidget);
      expect(find.text('Unassigned (1)'), findsOneWidget);
      await tester.tap(find.text('Unassigned (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 tasks shown'), findsOneWidget);
      expect(find.text('Overdue unassigned'), findsOneWidget);
      expect(find.text('Due today'), findsNothing);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upcoming (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 tasks shown'), findsOneWidget);
      expect(find.text('Due tomorrow'), findsOneWidget);
      await tester.tap(find.text('Upcoming (1)'));
      await tester.pumpAndSettle();
      expect(find.text('4 tasks shown'), findsOneWidget);
      await tester.tap(find.text('Unscheduled (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 tasks shown'), findsOneWidget);
      expect(find.text('No date'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final completed in [false, true]) {
    testWidgets(
      'deleting the last unlinked task resets client filter: completed=$completed',
      (tester) async {
        final db = FakeFirebaseFirestore();
        final service = FirestoreService(firestore: db);
        await db
            .collection('clients')
            .doc('linked')
            .set(_client('linked', 'Linked customer').toFirestore());
        for (final plan in [
          _plan('first', 'missing-1', completed: completed),
          _plan('second', 'missing-2', completed: completed),
          _plan('remaining', 'linked', completed: completed),
        ]) {
          await db.collection('plans').doc(plan.id).set(plan.toFirestore());
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
              firestoreServiceProvider.overrideWithValue(service),
              clientsListProvider.overrideWith(
                (ref) => service.getClientsOnce(),
              ),
              currentUserProfileProvider.overrideWith(
                (ref) async => AppUser(
                  uid: 'admin',
                  email: '',
                  name: 'Admin',
                  isAdmin: true,
                ),
              ),
              allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
              allPlansStreamProvider.overrideWith(
                (ref) => db
                    .collection('plans')
                    .snapshots()
                    .map(
                      (snapshot) =>
                          snapshot.docs.map(Plan.fromFirestore).toList(),
                    ),
              ),
            ],
            child: MaterialApp(
              home: completed
                  ? const CompletedTasksScreen()
                  : const TasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final filter = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == 'Client',
        );
        await tester.tap(filter);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unlinked tasks'));
        await tester.pumpAndSettle();
        expect(find.text('2 tasks shown'), findsOneWidget);
        await service.deletePlanTask('first', 'first work', 'DELETE');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('1 tasks shown'), findsOneWidget);
        expect(
          tester.widget<DropdownButtonFormField<String>>(filter).initialValue,
          '__unlinked_tasks__',
        );
        await service.deletePlanTask('second', 'second work', 'DELETE');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<DropdownButtonFormField<String>>(filter).initialValue,
          isNull,
        );
        expect(find.text('remaining work'), findsOneWidget);
        await tester.tap(filter);
        await tester.pumpAndSettle();
        expect(find.text('Unlinked tasks'), findsNothing);
        await tester.tap(find.text('All').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'client relinking and staff removal clear stale filter selections',
    (tester) async {
      final plans = StreamController<List<Plan>>();
      final users = StreamController<List<AppUser>>();
      final client = _client('linked', 'Linked customer');
      final staff = AppUser(
        uid: 'staff',
        email: '',
        name: 'Assigned person',
        isAdmin: false,
      );
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          currentUserProfileProvider.overrideWith(
            (ref) async =>
                AppUser(uid: 'admin', email: '', name: 'Admin', isAdmin: true),
          ),
          clientsListProvider.overrideWith((ref) async => [client]),
          taskClientsProvider.overrideWith((ref) async => [client]),
          allPlansStreamProvider.overrideWith((ref) => plans.stream),
          allUsersProvider.overrideWith((ref) => users.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await plans.close();
        await users.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TasksScreen()),
        ),
      );
      plans.add([_plan('task', 'missing')]);
      users.add([staff]);
      await tester.pumpAndSettle();
      Finder filter(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == label,
      );
      await tester.tap(filter('Client'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlinked tasks'));
      await tester.pumpAndSettle();
      await tester.tap(filter('Assigned staff'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assigned person').last);
      await tester.pumpAndSettle();
      plans.add([_plan('task', 'linked')]);
      users.add([]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(filter('Client'))
            .initialValue,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(filter('Assigned staff'))
            .initialValue,
        isNull,
      );
      expect(find.text('task work'), findsOneWidget);
      expect(tester.takeException(), isNull);
      plans.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No tasks found in assigned plans'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('duplicate filtering does not remove exact task client links', () async {
    final service = await _service();
    final clients = await service.getClientsOnce();
    expect(clients.map((client) => client.id), [_phone]);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(service),
        clientsListProvider.overrideWith((ref) async => clients),
        visiblePlansProvider.overrideWith(
          (ref) => AsyncData([
            _plan('first', 'legacy'),
            _plan('second', 'legacy'),
            _plan('canonical', _phone),
            _plan('practice', '__internal_practice__'),
            _plan('unlinked', ''),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final resolved = await container.read(taskClientsProvider.future);
    expect(resolved.map((client) => client.id), [_phone, 'legacy']);
    expect(resolved.last.name, 'Original linked customer');
    expect(service.lookups, ['legacy']);
    expect(clients.map((client) => client.id), [_phone]);
  });

  test(
    'task-only updates reuse client resolution; new IDs trigger a lookup',
    () async {
      final service = await _service();
      final plans = StreamController<List<Plan>>();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(service),
          clientsListProvider.overrideWith((ref) => service.getClientsOnce()),
          allPlansStreamProvider.overrideWith((ref) => plans.stream),
        ],
      );
      final listener = container.listen(taskClientsProvider, (_, _) {});
      addTearDown(() async {
        listener.close();
        container.dispose();
        await plans.close();
      });
      plans.add([_plan('first', 'legacy')]);
      await Future<void>.delayed(Duration.zero);
      await container.read(taskClientsProvider.future);
      expect(service.lookups, ['legacy']);
      plans.add([_plan('first', 'legacy').copyWith(price: 10)]);
      await Future<void>.delayed(Duration.zero);
      await container.read(taskClientsProvider.future);
      expect(service.lookups, ['legacy']);
      plans.add([_plan('first', 'legacy'), _plan('missing', 'deleted')]);
      await Future<void>.delayed(Duration.zero);
      await container.read(taskClientsProvider.future);
      expect(service.lookups, ['legacy', 'legacy', 'deleted']);
    },
  );

  for (final personal in [false, true]) {
    for (final completed in [false, true]) {
      testWidgets(
        'task client names resolve by ID: personal=$personal completed=$completed',
        (tester) async {
          final service = await _service();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authStateProvider.overrideWith((ref) => Stream.value(null)),
                firestoreServiceProvider.overrideWithValue(service),
                clientsListProvider.overrideWith(
                  (ref) => service.getClientsOnce(),
                ),
                currentStaffIdsProvider.overrideWithValue(['staff']),
                currentUserProfileProvider.overrideWith(
                  (ref) async => AppUser(
                    uid: 'staff',
                    email: '',
                    name: 'Staff',
                    isAdmin: !personal,
                    isStaff: true,
                  ),
                ),
                allUsersProvider.overrideWith(
                  (ref) => Stream.value(<AppUser>[]),
                ),
                allPlansStreamProvider.overrideWith(
                  (ref) => Stream.value([
                    _plan('legacy', 'legacy', completed: completed),
                    _plan('missing', 'deleted', completed: completed),
                    _plan(
                      'practice',
                      '__internal_practice__',
                      completed: completed,
                    ),
                  ]),
                ),
              ],
              child: MaterialApp(
                home: personal
                    ? completed
                          ? const MyCompletedTasksScreen()
                          : const MyAssignedTasksScreen()
                    : completed
                    ? const CompletedTasksScreen()
                    : const TasksScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (personal && completed) {
            expect(find.textContaining('Today & Overdue'), findsNothing);
            expect(find.textContaining('Upcoming'), findsNothing);
            expect(find.textContaining('Unscheduled'), findsNothing);
          }
          expect(
            find.textContaining('Client: Original linked customer'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Client: No client linked'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Client: Practice (Internal)'),
            findsOneWidget,
          );
          expect(find.textContaining('Unknown client'), findsNothing);
          expect(service.lookups, ['legacy', 'deleted']);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('lookup errors show Retry instead of a missing-client label', (
    tester,
  ) async {
    final service = (await _service())..failLookup = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(service),
          clientsListProvider.overrideWith((ref) => service.getClientsOnce()),
          currentUserProfileProvider.overrideWith(
            (ref) async =>
                AppUser(uid: 'admin', email: '', name: 'Admin', isAdmin: true),
          ),
          allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
          allPlansStreamProvider.overrideWith(
            (ref) => Stream.value([_plan('legacy', 'legacy')]),
          ),
        ],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Error loading task clients:'), findsOneWidget);
    expect(find.textContaining('No client linked'), findsNothing);
    service.failLookup = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Client: Original linked customer'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all missing client IDs share one Unlinked tasks filter', (
    tester,
  ) async {
    final service = await _service();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(service),
          clientsListProvider.overrideWith((ref) => service.getClientsOnce()),
          currentUserProfileProvider.overrideWith(
            (ref) async =>
                AppUser(uid: 'admin', email: '', name: 'Admin', isAdmin: true),
          ),
          allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
          allPlansStreamProvider.overrideWith(
            (ref) => Stream.value([
              _plan('first missing', 'missing-1'),
              _plan('second missing', 'missing-2'),
              _plan('linked', 'legacy'),
            ]),
          ),
        ],
        child: const MaterialApp(home: TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Client: No client linked'), findsNWidgets(2));
    expect(find.textContaining('missing-1'), findsNothing);
    expect(find.textContaining('missing-2'), findsNothing);
    final filter = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Client',
    );
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.text('Unlinked tasks'), findsOneWidget);
    await tester.tap(find.text('Unlinked tasks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Client: No client linked'), findsNWidgets(2));
    expect(
      find.textContaining('Client: Original linked customer'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
