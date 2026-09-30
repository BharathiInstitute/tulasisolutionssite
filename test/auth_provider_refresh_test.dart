import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/performance/performance_models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/features/admin/tasks/my_assigned_tasks_screen.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';
import 'package:tulasisolutionssite/features/admin/users/user_management_screen.dart';

class _TestUser implements User {
  @override
  final String uid;

  @override
  final String? email;

  _TestUser(this.uid, {this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthService implements FirebaseAuthService {
  final requestedProfiles = <String>[];

  @override
  Future<AppUser?> getUserProfile(String uid) async {
    requestedProfiles.add(uid);
    return AppUser(uid: uid, email: '', name: uid, isAdmin: uid == 'admin');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestFirestoreService implements FirestoreService {
  int subscriptions = 0;
  int planSubscriptions = 0;
  final performanceQueries = <String, List<String>?>{};
  final deletedStaff = <String>[];

  @override
  Future<void> deleteStaffMember(String uid, String confirmation) async {
    expect(confirmation, 'DELETE');
    deletedStaff.add(uid);
  }

  @override
  Stream<List<Plan>> getAllPlansStream() {
    planSubscriptions++;
    if (planSubscriptions == 1) {
      return Stream.error(StateError('permission-denied'));
    }
    return Stream.value(<Plan>[]);
  }

  @override
  Stream<List<VideoSubmission>> getPerformanceSubmissionsStream({
    List<String>? staffIds,
  }) {
    performanceQueries['submissions'] = staffIds;
    return Stream.value([]);
  }

  @override
  Stream<List<DailyHours>> getPerformanceHoursStream({List<String>? staffIds}) {
    performanceQueries['hours'] = staffIds;
    return Stream.value([]);
  }

  @override
  Stream<List<AttendanceRecord>> getPerformanceAttendanceStream({
    List<String>? staffIds,
  }) {
    performanceQueries['attendance'] = staffIds;
    return Stream.value([]);
  }

  @override
  Stream<List<AppUser>> getUsersStream() {
    subscriptions++;
    if (subscriptions == 1) {
      return Stream.error(StateError('permission-denied'));
    }
    return Stream.value(<AppUser>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('staff deletion requires typed confirmation and protects admin', (
    tester,
  ) async {
    final service = _TestFirestoreService();
    final admin = AppUser(
      uid: 'admin',
      email: 'admin@example.com',
      name: 'Admin',
      isAdmin: true,
    );
    final staff = AppUser(
      uid: 'staff@example.com',
      email: 'staff@example.com',
      name: 'Staff',
      isAdmin: false,
      isStaff: true,
    );
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(_TestUser('admin', email: admin.email)),
        ),
        currentUserProfileProvider.overrideWith((ref) async => admin),
        firestoreServiceProvider.overrideWithValue(service),
        allUsersProvider.overrideWith(
          (ref) => Stream.value([
            admin,
            if (!service.deletedStaff.contains(staff.uid)) staff,
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: UserManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final deleteIcons = find.widgetWithIcon(IconButton, Icons.delete_outline);
    expect(tester.widget<IconButton>(deleteIcons.first).onPressed, isNull);
    await tester.tap(deleteIcons.last);
    await tester.pumpAndSettle();
    final deleteButton = find.widgetWithText(FilledButton, 'Delete');
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.deletedStaff, isEmpty);

    await tester.tap(deleteIcons.last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(service.deletedStaff, [staff.uid]);
    expect(find.text('Staff'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('staff task views show old and new assignments and live edits', (
    tester,
  ) async {
    final plans = StreamController<List<Plan>>();
    addTearDown(plans.close);
    final container = ProviderContainer(
      overrides: [
        currentStaffIdsProvider.overrideWithValue([
          'staff-auth-uid',
          'staff@example.com',
        ]),
        currentUserProfileProvider.overrideWith(
          (ref) async => AppUser(
            uid: 'staff@example.com',
            email: 'staff@example.com',
            name: 'Staff',
            isAdmin: false,
            isStaff: true,
          ),
        ),
        allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
        allPlansStreamProvider.overrideWith((ref) => plans.stream),
      ],
    );
    addTearDown(container.dispose);
    final plan = Plan(
      id: 'plan-1',
      clientId: 'client-1',
      type: PlanType.setup,
      name: 'Plan',
      price: 0,
      startDate: DateTime(2024, 1, 1),
      features: const [
        'Content: Legacy task',
        'Content: New task',
        'Content: Other staff task',
        'Content: Completed task',
      ],
      taskWorkflow: const {
        'Content: Legacy task': {'assignedTo': 'staff@example.com'},
        'Content: New task': {'assignedTo': 'staff-auth-uid'},
        'Content: Other staff task': {'assignedTo': 'other-staff'},
        'Content: Completed task': {
          'assignedTo': 'staff@example.com',
          'status': 'completed',
        },
      },
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyAssignedTasksScreen()),
      ),
    );
    plans.add([plan]);
    await tester.pumpAndSettle();
    expect(find.text('Legacy task'), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Other staff task'), findsNothing);
    expect(find.text('Completed task'), findsNothing);
    expect(
      tester
          .widgetList<TaskRow>(find.byType(TaskRow))
          .map((row) => row.lockedAssigneeId),
      ['staff@example.com', 'staff-auth-uid'],
    );

    plans.add([
      renamePlanTask(
        plan,
        'Content: Legacy task',
        category: 'Content',
        title: 'Updated task',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Legacy task'), findsNothing);
    expect(find.text('Updated task'), findsOneWidget);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyCompletedTasksScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed task'), findsOneWidget);
    expect(find.text('New task'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'staff identities include login UID and legacy email assignments',
    () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              _TestUser('staff-auth-uid', email: 'staff@example.com'),
            ),
          ),
          currentUserProfileProvider.overrideWith(
            (ref) async => AppUser(
              uid: 'legacy-staff-id',
              email: 'staff@example.com',
              name: 'Staff',
              isAdmin: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      await container.read(currentUserProfileProvider.future);
      expect(container.read(currentStaffIdsProvider), [
        'staff-auth-uid',
        'staff@example.com',
        'legacy-staff-id',
      ]);
    },
  );

  test(
    'plan subscriptions wait for login and recover on retry and account changes',
    () async {
      final authChanges = StreamController<User?>();
      final firestoreService = _TestFirestoreService();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => authChanges.stream),
          firestoreServiceProvider.overrideWithValue(firestoreService),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await authChanges.close();
      });
      container.listen(allPlansStreamProvider, (previous, next) {});

      expect(await container.read(allPlansStreamProvider.future), isEmpty);
      expect(firestoreService.planSubscriptions, 0);

      authChanges.add(_TestUser('staff'));
      await container.pump();
      await expectLater(
        container.read(allPlansStreamProvider.future),
        throwsStateError,
      );

      container.invalidate(allPlansStreamProvider);
      expect(await container.read(allPlansStreamProvider.future), isEmpty);
      expect(firestoreService.planSubscriptions, 2);

      authChanges.add(_TestUser('other-staff'));
      await container.pump();
      expect(await container.read(allPlansStreamProvider.future), isEmpty);
      expect(firestoreService.planSubscriptions, 3);

      authChanges.add(null);
      await container.pump();
      expect(await container.read(allPlansStreamProvider.future), isEmpty);
      expect(firestoreService.planSubscriptions, 3);
    },
  );

  test(
    'personal performance streams use only current staff identities',
    () async {
      final firestoreService = _TestFirestoreService();
      final staffIds = ['staff-auth-uid', 'staff@example.com'];
      final container = ProviderContainer(
        overrides: [
          currentStaffIdsProvider.overrideWithValue(staffIds),
          firestoreServiceProvider.overrideWithValue(firestoreService),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(myPerformanceSubmissionsProvider.future),
        isEmpty,
      );
      expect(await container.read(myPerformanceHoursProvider.future), isEmpty);
      expect(
        await container.read(myPerformanceAttendanceProvider.future),
        isEmpty,
      );
      expect(firestoreService.performanceQueries, {
        'submissions': staffIds,
        'hours': staffIds,
        'attendance': staffIds,
      });
    },
  );

  test('signed-out personal streams do not request performance data', () async {
    final firestoreService = _TestFirestoreService();
    final container = ProviderContainer(
      overrides: [
        currentStaffIdsProvider.overrideWithValue([]),
        firestoreServiceProvider.overrideWithValue(firestoreService),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(myPerformanceSubmissionsProvider.future),
      isEmpty,
    );
    expect(await container.read(myPerformanceHoursProvider.future), isEmpty);
    expect(
      await container.read(myPerformanceAttendanceProvider.future),
      isEmpty,
    );
    expect(firestoreService.performanceQueries, isEmpty);
  });

  test(
    'account changes reload profiles and failed staff subscriptions',
    () async {
      final authChanges = StreamController<User?>();
      final authService = _TestAuthService();
      final firestoreService = _TestFirestoreService();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => authChanges.stream),
          firebaseAuthServiceProvider.overrideWithValue(authService),
          firestoreServiceProvider.overrideWithValue(firestoreService),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await authChanges.close();
      });
      container.listen(currentUserProfileProvider, (previous, next) {});
      container.listen(allUsersProvider, (previous, next) {});

      await container.read(allUsersProvider.future);
      authChanges.add(_TestUser('staff'));
      await container.pump();
      expect(
        (await container.read(currentUserProfileProvider.future))?.uid,
        'staff',
      );
      await expectLater(
        container.read(allUsersProvider.future),
        throwsStateError,
      );

      authChanges.add(_TestUser('admin'));
      await container.pump();
      expect(
        (await container.read(currentUserProfileProvider.future))?.isAdmin,
        isTrue,
      );
      expect(await container.read(allUsersProvider.future), isEmpty);
      expect(firestoreService.subscriptions, 2);
      expect(authService.requestedProfiles, ['staff', 'admin']);

      authChanges.add(null);
      await container.pump();
      expect(await container.read(currentUserProfileProvider.future), isNull);
      expect(await container.read(allUsersProvider.future), isEmpty);
    },
  );
}
