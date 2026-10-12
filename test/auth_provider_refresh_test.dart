import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/performance/performance_models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/features/admin/tasks/my_assigned_tasks_screen.dart';
import 'package:tulasisolutionssite/features/admin/client_list/client_list_screen.dart';
import 'package:tulasisolutionssite/features/admin/tasks/tasks_screen.dart';
import 'package:tulasisolutionssite/features/admin/tasks/sales_record_dialog.dart';
import 'package:tulasisolutionssite/features/admin/tasks/sales_tasks_tab.dart';
import 'package:tulasisolutionssite/features/admin/users/user_management_screen.dart';
import 'package:tulasisolutionssite/features/auth/auth_screen.dart';
import 'package:tulasisolutionssite/features/auth/auth_guard_screen.dart';

class _TestUser implements User {
  @override
  final String uid;

  @override
  final String? email;

  _TestUser(this.uid, {this.email});

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileAuth extends Fake implements FirebaseAuth {
  @override
  final User? currentUser;

  _ProfileAuth(this.currentUser);
}

class _ProfileApp extends Fake implements FirebaseApp {
  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test',
    appId: 'test',
    messagingSenderId: 'test',
    projectId: 'profile-test',
  );
}

class _ProfileFirestore extends Fake implements FirebaseFirestore {
  @override
  FirebaseApp get app => _ProfileApp();
}

class _UnavailableProfileService extends FirebaseAuthService {
  _UnavailableProfileService({required User user, required http.Client client})
    : super(
        auth: _ProfileAuth(user),
        firestore: _ProfileFirestore(),
        profileHttpClient: client,
      );

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(
    String documentId,
  ) async {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

class _TestAuthService implements FirebaseAuthService {
  final requestedProfiles = <String>[];
  final Map<String, List<Object>> profileErrors;

  _TestAuthService({this.profileErrors = const {}});

  @override
  User? getCurrentUser() => null;

  @override
  Future<AppUser?> getUserProfile(String uid) async {
    requestedProfiles.add(uid);
    final errors = profileErrors[uid];
    if (errors != null && errors.isNotEmpty) throw errors.removeAt(0);
    return AppUser(uid: uid, email: '', name: uid, isAdmin: uid == 'admin');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DirectHttpProfileService extends _UnavailableProfileService {
  int sdkReads = 0;

  _DirectHttpProfileService({required super.user, required super.client});

  @override
  bool get useHttpProfileReads => true;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(
    String documentId,
  ) {
    sdkReads++;
    return Completer<DocumentSnapshot<Map<String, dynamic>>>().future;
  }
}

class _PendingProfileService extends _TestAuthService {
  final pending = Completer<AppUser?>();

  @override
  Future<AppUser?> getUserProfile(String uid) {
    requestedProfiles.add(uid);
    return pending.future;
  }
}

class _TestFirestoreService implements FirestoreService {
  int subscriptions = 0;
  int planSubscriptions = 0;
  final performanceQueries = <String, List<String>?>{};
  final deletedStaff = <String>[];
  final createdPlans = <Plan>[];
  final updatedPlans = <Plan>[];
  final recordedContacts = <Map<String, dynamic>>[];
  final savedSalesRecords = <Map<String, dynamic>>[];
  final savedSalesClients = <String, Client>{};

  @override
  Stream<List<Map<String, dynamic>>> salesActivity(String clientId) =>
      Stream.value([]);

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
    savedSalesRecords.add({
      'client': client,
      'stage': stage,
      'progress': progress,
      'dueAt': dueAt,
      'doNotContact': doNotContact,
      'notes': notes,
    });
    return client.copyWith(
      stage: stage,
      salesProgress: progress,
      followUpAt: dueAt,
      followUpNotes: client.followUpNotes,
      clearFollowUp: true,
      doNotContact: doNotContact,
      salesRecord: {
        ...client.salesRecord,
        'title': progress ?? 'Sales follow-up',
        'action': 'Update',
        'notes': notes ?? '',
        'status': 'assigned',
        'dueAt': dueAt?.toIso8601String(),
        'assignedTo': actor.uid,
        'revision': 'saved-${savedSalesRecords.length}',
      },
    );
  }

  @override
  Future<Client> saveCustomerSalesRecord({
    required Client client,
    required AppUser actor,
    required String title,
    required String action,
    required String notes,
    required String outcome,
    required bool completeAction,
    required DateTime? dueAt,
    required String nextTitle,
    required String nextAction,
    required ClientStage stage,
    SalesTask? legacyTask,
    String? customerResponse,
    String? nextStep,
    int? reminderDays,
    int? reminderTimeMinutes,
    bool? doNotContact,
    String? progress,
    bool updateOnly = false,
  }) async {
    savedSalesRecords.add({
      'client': client,
      'notes': notes,
      'outcome': outcome,
      'dueAt': dueAt,
      'action': action,
      'customerResponse': customerResponse,
      'nextStep': nextStep,
      'reminderDays': reminderDays,
      'reminderTimeMinutes': reminderTimeMinutes,
      'progress': progress,
    });
    return client;
  }

  @override
  Future<Client?> getClient(String id, {bool serverOnly = false}) async =>
      savedSalesClients[id];

  @override
  Future<void> saveSalesRecord({
    required Client client,
    required Plan? plan,
    required String? feature,
    required bool addTask,
    required String notes,
    required DateTime? dueAt,
    required ClientStage stage,
    required List<Map<String, dynamic>> contacts,
    required bool editCustomer,
    required bool editTask,
    AppUser? actor,
    String? nextFeature,
  }) async {
    savedSalesClients[client.id] = client;
    savedSalesRecords.add({
      'client': client,
      'plan': plan,
      'feature': feature,
      'notes': notes,
      'dueAt': dueAt,
      'stage': stage,
      'contacts': contacts,
      'editCustomer': editCustomer,
      'editTask': editTask,
      'nextFeature': nextFeature,
    });
    if (editTask && plan != null && feature != null) {
      final updated = updateSalesRecordTask(plan, feature, notes, dueAt);
      if (addTask) {
        createdPlans.add(updated);
      } else {
        updatedPlans.add(updated);
      }
    }
  }

  @override
  Future<void> recordSalesContact({
    required String clientId,
    required String method,
    required String outcome,
    required String notes,
    required String recordedBy,
    ClientStage? stage,
  }) async {
    recordedContacts.add({
      'clientId': clientId,
      'method': method,
      'outcome': outcome,
      'notes': notes,
      'recordedBy': recordedBy,
      'stage': stage,
    });
  }

  @override
  Future<void> createPlan(Plan plan, {bool ifAbsent = false}) async {
    expect(
      plan.id,
      isNot(matches(r'^__.*__$')),
      reason: 'Firestore reserves document IDs matching __.*__.',
    );
    createdPlans.add(plan);
  }

  @override
  Future<void> updatePlan(Plan plan, {Plan? previous}) async {
    updatedPlans.add(plan);
  }

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
  testWidgets('login toggles password visibility without changing its value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );

    final passwordField = find.byType(TextFormField).last;
    final passwordInput = find.descendant(
      of: passwordField,
      matching: find.byType(EditableText),
    );
    await tester.enterText(passwordField, 'test-password');

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Admin Login'), findsNothing);
    expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<EditableText>(passwordInput).obscureText, isFalse);
    expect(
      tester.widget<EditableText>(passwordInput).controller.text,
      'test-password',
    );

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);
    expect(
      tester.widget<EditableText>(passwordInput).controller.text,
      'test-password',
    );
  });

  test(
    'sales record creates a shared task and task-only edits leave customer history unchanged',
    () async {
      final firestore = FakeFirebaseFirestore();
      final client = Client(
        id: 'lead',
        name: 'Customer',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        createdDate: DateTime(2026),
        notes: 'Customer background',
      );
      await firestore.doc('clients/lead').set(client.toFirestore());
      final task = ClientTask(
        id: 'task-id',
        category: 'Sales / WhatsApp',
        title: 'Send proposal',
        order: 0,
        source: ClientTaskSource.customIncluded,
        addedReason: 'Next action',
      );
      final plan = updateTaskAssignment(
        Plan(
          id: 'sales',
          clientId: client.id,
          type: PlanType.setup,
          name: 'Sales Tasks',
          price: 0,
          startDate: DateTime(2026),
          features: [task.feature],
          tasks: [task],
        ),
        task.feature,
        assignedTo: 'me',
        assignedToName: 'Me',
        priority: 'normal',
      );
      final service = FirestoreService(firestore: firestore);
      await service.saveSalesRecord(
        client: client,
        plan: plan,
        feature: task.feature,
        addTask: true,
        notes: 'Shared proposal note',
        dueAt: DateTime(2026, 10, 10),
        stage: ClientStage.followUp,
        contacts: const [
          {
            'id': 'new',
            'method': 'WhatsApp',
            'outcome': 'Interested',
            'notes': 'Proposal discussed',
          },
        ],
        editCustomer: true,
        editTask: true,
      );
      final storedPlan = Plan.fromFirestore(
        await firestore.doc('plans/sales').get(),
      );
      final customerSnapshot = (await firestore.doc('clients/lead').get())
          .data();
      expect(storedPlan.price, 0);
      expect(storedPlan.tasks.single.id, 'task-id');
      expect(taskAssigneeId(storedPlan, task.feature), 'me');
      expect(taskDueAt(storedPlan, task.feature), DateTime(2026, 10, 10));
      expect(
        taskInternalNotes(storedPlan, task.feature),
        'Shared proposal note',
      );
      expect(
        customerSnapshot!['stage'],
        ClientStage.fromStoredName(ClientStage.followUp.name).name,
      );
      await service.saveSalesRecord(
        client: client,
        plan: storedPlan,
        feature: task.feature,
        addTask: false,
        notes: 'Task-only edit',
        dueAt: null,
        stage: ClientStage.client,
        contacts: const [],
        editCustomer: false,
        editTask: true,
      );
      final editedPlan = Plan.fromFirestore(
        await firestore.doc('plans/sales').get(),
      );
      expect(taskInternalNotes(editedPlan, task.feature), 'Task-only edit');
      expect(taskDueAt(editedPlan, task.feature), isNull);
      expect(
        (await firestore.doc('clients/lead').get()).data(),
        customerSnapshot,
      );
    },
  );

  test(
    'sales record transaction preserves live task progress and concurrent contacts',
    () async {
      final client = Client(
        id: 'lead',
        name: 'Customer',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        createdDate: DateTime(2026),
        notes: 'Legacy',
        followUpNotes: 'Old follow-up',
        salesContacts: const [
          {
            'id': 'old',
            'method': 'Call',
            'outcome': 'Interested',
            'notes': 'Original',
          },
        ],
      );
      const feature = 'Sales / Call: Next call';
      final plan = Plan(
        id: 'sales',
        clientId: client.id,
        type: PlanType.setup,
        name: 'Sales Tasks',
        price: 0,
        startDate: DateTime(2026),
        features: const [feature],
        taskWorkflow: const {
          feature: {'assignedTo': 'staff', 'internalNotes': 'Old task note'},
        },
      );
      final documents = <String, Map<String, dynamic>>{
        'clients/lead': {
          ...client.toFirestore(),
          'salesContacts': [
            ...client.salesContacts,
            {'id': 'concurrent', 'notes': 'Added elsewhere'},
          ],
        },
        'plans/sales': {
          ...plan.toFirestore(),
          'taskWorkflow': {
            feature: {
              ...plan.taskWorkflow[feature]!,
              'status': 'working',
              'elapsedSeconds': 300,
            },
            'Other feature': {'internalNotes': 'Keep this'},
          },
        },
      };
      final firestore = FakeFirebaseFirestore();
      for (final entry in documents.entries) {
        await firestore.doc(entry.key).set(entry.value);
      }
      final service = FirestoreService(firestore: firestore);
      Future<void> save() => service.saveSalesRecord(
        client: client,
        plan: plan,
        feature: feature,
        addTask: false,
        notes: 'Merged edited notes',
        dueAt: DateTime(2026, 11, 4),
        stage: client.stage,
        contacts: [
          {...client.salesContacts.single, 'notes': 'Corrected'},
        ],
        editCustomer: true,
        editTask: true,
      );
      await save();
      final savedPlan = (await firestore.doc('plans/sales').get()).data()!;
      final savedClient = (await firestore.doc('clients/lead').get()).data()!;
      final workflow = savedPlan['taskWorkflow'] as Map;
      expect(workflow[feature]['status'], 'working');
      expect(workflow[feature]['assignedTo'], 'staff');
      expect(workflow[feature]['elapsedSeconds'], 300);
      expect(workflow[feature]['internalNotes'], 'Merged edited notes');
      expect(workflow[feature]['salesRecordMerged'], true);
      expect(workflow['Other feature']['internalNotes'], 'Keep this');
      expect(savedClient['salesContacts'], [
        {...client.salesContacts.single, 'notes': 'Corrected'},
        {'id': 'concurrent', 'notes': 'Added elsewhere'},
      ]);
      expect(savedClient['followUpNotes'], isNull);
      await expectLater(save(), throwsStateError);
      expect((await firestore.doc('plans/sales').get()).data(), savedPlan);
      expect((await firestore.doc('clients/lead').get()).data(), savedClient);
    },
  );

  testWidgets(
    'selected Sales filter survives completion, archiving, and removal',
    (tester) async {
      final changes = StreamController<List<Plan>>();
      addTearDown(changes.close);
      final profile = AppUser(
        uid: 'admin',
        email: '',
        name: 'Admin',
        isAdmin: true,
      );
      final client = Client(
        id: 'lead',
        name: 'Sales Customer',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        createdDate: DateTime(2026, 10, 2),
      );
      const feature = 'Sales / Call: Last sales call';
      final sales = Plan(
        id: 'sales',
        clientId: client.id,
        type: PlanType.setup,
        name: 'Sales Tasks',
        price: 0,
        startDate: DateTime(2026, 10, 2),
        features: const [feature],
        taskWorkflow: const {
          feature: {'assignedTo': 'admin'},
        },
      );
      final delivery = Plan(
        id: 'delivery',
        clientId: client.id,
        type: PlanType.setup,
        name: 'Delivery',
        price: 0,
        startDate: DateTime(2026, 10, 2),
        features: const ['Content: Delivery work'],
      );
      final container = ProviderContainer(
        overrides: [
          firebaseAuthServiceProvider.overrideWithValue(_TestAuthService()),
          currentUserProfileProvider.overrideWith((ref) async => profile),
          allUsersProvider.overrideWith((ref) => Stream.value([profile])),
          allPlansStreamProvider.overrideWith((ref) => changes.stream),
          clientsListProvider.overrideWith((ref) async => [client]),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/admin/tasks',
        routes: [
          GoRoute(path: '/admin/tasks', builder: (_, _) => const TasksScreen()),
        ],
      );
      addTearDown(router.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      changes.add([sales, delivery]);
      await tester.pumpAndSettle();
      final categoryFilter = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Task category',
      );
      await tester.tap(categoryFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales').last);
      await tester.pumpAndSettle();
      expect(find.text('Last sales call'), findsOneWidget);
      for (final nextPlans in [
        [
          sales.copyWith(
            taskWorkflow: const {
              feature: {'assignedTo': 'admin', 'status': 'completed'},
            },
          ),
          delivery,
        ],
        [setTaskArchived(sales, feature, true), delivery],
        [delivery],
      ]) {
        changes.add(nextPlans);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          categoryFilter,
        );
        expect(dropdown.initialValue, 'Sales');
        expect(
          find.descendant(of: categoryFilter, matching: find.text('Sales')),
          findsOneWidget,
        );
        expect(find.text('Last sales call'), findsNothing);
        expect(find.text('0 tasks shown'), findsOneWidget);
      }
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Delivery work'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Sales panel shows the linked customer and preserves staff completion restrictions',
    (tester) async {
      final profile = AppUser(
        uid: 'sales-staff',
        email: 'sales@example.com',
        name: 'Sales Staff',
        isAdmin: false,
        isStaff: true,
        panels: const ['myTasks', 'leads'],
      );
      final client = Client(
        id: 'linked-lead',
        name: 'Sales Customer',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.consult,
        createdDate: DateTime.now(),
      );
      const feature = 'Sales / Call: Follow up pricing';
      final plan = Plan(
        id: 'sales-plan',
        clientId: client.id,
        type: PlanType.setup,
        name: 'Sales Tasks',
        price: 0,
        startDate: DateTime.now(),
        features: const [feature],
        taskWorkflow: {
          feature: {'assignedTo': profile.uid, 'assignedToName': profile.name},
        },
      );
      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(_TestFirestoreService()),
          firebaseAuthServiceProvider.overrideWithValue(_TestAuthService()),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_TestUser(profile.uid, email: profile.email)),
          ),
          currentUserProfileProvider.overrideWith((ref) async => profile),
          allPlansStreamProvider.overrideWith((ref) => Stream.value([plan])),
          allUsersProvider.overrideWith((ref) => Stream.value([profile])),
          clientsListProvider.overrideWith((ref) async => [client]),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/admin/sales-tasks',
        routes: [
          GoRoute(
            path: '/admin/sales-tasks',
            builder: (_, _) => const SalesTasksScreen(),
          ),
          GoRoute(
            path: '/admin/leads/:clientId',
            builder: (_, state) => Scaffold(
              body: Text('Opened ${state.pathParameters['clientId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unscheduled (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Sales Customer'), findsOneWidget);
      await tester.tap(find.text('Follow up pricing'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesRecordDialog), findsOneWidget);
      expect(find.text('Drafts'), findsNothing);
      expect(find.text('Complete'), findsNothing);
      expect(find.text('Schedule next follow-up'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final changeStage in [false, true]) {
    testWidgets(
      'contact logging changes stage only when selected: $changeStage',
      (tester) async {
        final service = _TestFirestoreService();
        final client = Client(
          id: 'contact-lead',
          name: 'Contact Lead',
          category: '',
          contactEmail: '',
          contactPhone: '',
          stage: ClientStage.click,
          createdDate: DateTime(2026, 10, 2),
        );
        final profile = AppUser(
          uid: 'staff',
          email: '',
          name: 'Staff',
          isAdmin: true,
        );
        final container = ProviderContainer(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) async => profile),
            firestoreServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SalesContactDialog(client: client),
                    ),
                    child: const Text('Open contact'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open contact'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Customer requested pricing',
        );
        if (changeStage) {
          await tester.ensureVisible(
            find.byType(DropdownButtonFormField<ClientStage>),
          );
          await tester.tap(find.byType(DropdownButtonFormField<ClientStage>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Pitch').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(service.recordedContacts.single, {
          'clientId': client.id,
          'method': 'Call',
          'outcome': 'Interested',
          'notes': 'Customer requested pricing',
          'recordedBy': profile.uid,
          'stage': changeStage ? ClientStage.register : null,
        });
        expect(service.createdPlans, isEmpty);
        expect(client.stage, ClientStage.click);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'sales record edits merged notes and contact history together on mobile',
    (tester) async {
      final service = _TestFirestoreService();
      final client = Client(
        id: 'lead',
        name: 'Customer',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.consult,
        createdDate: DateTime.now(),
        notes: 'Customer background',
        followUpNotes: 'Follow-up detail',
        followUpAt: DateTime.now().subtract(const Duration(days: 1)),
        salesContacts: const [
          {
            'id': 'contact',
            'method': 'Call',
            'outcome': 'Interested',
            'notes': 'Original contact',
            'recordedBy': 'other',
          },
        ],
      );
      const feature = 'Sales / Call: Customer call';
      final plan = Plan(
        id: 'sales',
        clientId: client.id,
        type: PlanType.setup,
        name: 'Sales Tasks',
        price: 0,
        startDate: DateTime.now(),
        features: const [feature],
        taskWorkflow: {
          feature: {
            'assignedTo': 'other',
            'internalNotes': 'Task detail',
            'dueAt': client.followUpAt!.toIso8601String(),
          },
        },
      );
      final profile = AppUser(
        uid: 'admin',
        email: '',
        name: 'Admin',
        isAdmin: true,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) async => profile),
            firestoreServiceProvider.overrideWithValue(service),
            currentStaffIdsProvider.overrideWith((ref) => [profile.uid]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        SalesRecordDialog(client: client, plans: [plan]),
                  ),
                  child: const Text('Open record'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open record'));
      await tester.pumpAndSettle();
      final notesField = find.byKey(const ValueKey('sales-record-notes'));
      expect(
        tester.widget<TextField>(notesField).controller!.text,
        'Task detail\n\nCustomer background\n\nFollow-up detail',
      );
      await tester.enterText(notesField, 'One shared sales note');
      await tester.ensureVisible(find.byTooltip('Clear reminder'));
      await tester.tap(find.byTooltip('Clear reminder'));
      await tester.ensureVisible(find.text('Contact entries'));
      await tester.tap(find.text('Contact entries'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('contact')));
      await tester.tap(find.text('Call - Interested'));
      await tester.pumpAndSettle();
      final contactNotes = find.widgetWithText(TextField, 'Contact notes');
      await tester.ensureVisible(contactNotes);
      await tester.enterText(contactNotes, 'Corrected contact');
      await tester.ensureVisible(find.byTooltip('Log contact'));
      await tester.tap(find.byTooltip('Log contact'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save sales record'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save sales record'));
      await tester.pumpAndSettle();
      final saved = service.savedSalesRecords.single;
      expect(saved['notes'], 'One shared sales note');
      expect(saved['dueAt'], isNull);
      final contacts = saved['contacts'] as List<Map<String, dynamic>>;
      expect(contacts.first['notes'], 'Corrected contact');
      expect(contacts.first['recordedBy'], 'other');
      expect(contacts.last['recordedBy'], profile.uid);
      expect(contacts.last['id'], isNotEmpty);
      expect(contacts, hasLength(2));
      expect(taskAssigneeId(service.updatedPlans.single, feature), 'other');
      expect(
        taskInternalNotes(service.updatedPlans.single, feature),
        'One shared sales note',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pipeline-only permission sees no-task customers and never reads tasks',
    (tester) async {
      final client = Client(
        id: 'lead',
        name: 'No scheduled task',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        createdDate: DateTime.now(),
      );
      final profile = AppUser(
        uid: 'pipeline-only',
        email: '',
        name: 'Pipeline Staff',
        isAdmin: false,
        isStaff: true,
        panels: const ['leads'],
      );
      var taskReads = 0;
      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => profile),
          clientsListProvider.overrideWith((ref) async => [client]),
          allPlansStreamProvider.overrideWith((ref) {
            taskReads++;
            return Stream.value(<Plan>[]);
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/admin/leads',
        routes: [
          GoRoute(
            path: '/admin/leads',
            builder: (_, _) => const ClientListScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No scheduled task'), findsOneWidget);
      expect(find.text('Sales Pipeline'), findsOneWidget);
      expect(find.text('Sales Tasks'), findsNothing);
      expect(find.byTooltip('Add lead'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byTooltip('Create sales task'), findsNothing);
      expect(taskReads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sales task reader sees loading error retry and archived customer without creation',
    (tester) async {
      final client = Client(
        id: 'archived-customer',
        name: 'Archived customer',
        clientCode: 'C-42',
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        isArchived: true,
        createdDate: DateTime.now(),
      );
      final plan = Plan(
        id: 'sales',
        clientId: client.id,
        name: 'Sales Tasks',
        type: PlanType.setup,
        price: 0,
        startDate: DateTime.now(),
        features: const ['Sales / Call: Call archived customer'],
        taskWorkflow: {
          'Sales / Call: Call archived customer': {
            'dueAt': DateTime.now().toIso8601String(),
            'assignedTo': 'reader',
          },
        },
      );
      final profile = AppUser(
        uid: 'reader',
        email: '',
        name: 'Reader',
        isAdmin: false,
        isStaff: true,
        panels: const ['leads', 'myTasks'],
      );
      final loading = StreamController<List<Plan>>();
      addTearDown(loading.close);
      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(_TestFirestoreService()),
          currentUserProfileProvider.overrideWith((ref) async => profile),
          clientsListProvider.overrideWith((ref) async => [client]),
          allPlansStreamProvider.overrideWith((ref) {
            reads++;
            return reads == 1 ? loading.stream : Stream.value([plan]);
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/admin/sales-tasks',
        routes: [
          GoRoute(
            path: '/admin/sales-tasks',
            builder: (_, _) => const SalesTasksScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      loading.addError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(find.text('Sales tasks could not be loaded.'), findsOneWidget);
      await tester.tap(find.text('Retry sales tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Archived customer'), findsOneWidget);
      expect(find.text('C-42'), findsNothing);
      expect(find.text('Create sales task'), findsNothing);
      expect(find.text('Open task'), findsNothing);
      final taskTile = find.ancestor(
        of: find.text('Archived customer'),
        matching: find.byType(ListTile),
      );
      await tester.tapAt(
        tester.getRect(taskTile).centerRight - const Offset(8, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SalesRecordDialog>(find.byType(SalesRecordDialog))
            .initialTask!
            .feature,
        plan.features.single,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pipeline is restored alongside Sales Tasks with creation and customer navigation',
    (tester) async {
      final dialedUrls = <String>[];
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        (call) async {
          if (call.method == 'launch') {
            dialedUrls.add((call.arguments as Map)['url'] as String);
            return true;
          }
          return false;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcherChannel,
          null,
        );
      });
      final service = _TestFirestoreService();
      final now = DateTime.now();
      Client lead(String id) => Client(
        id: id,
        name: id,
        category: '',
        contactEmail: '',
        contactPhone: '',
        stage: ClientStage.click,
        createdDate: now,
      );
      final clients = [
        lead('Overdue Lead').copyWith(
          stage: ClientStage.consult,
          notes: 'Manager note',
          contactPhone: '+91 98765 43210',
          followUpAt: now.add(const Duration(days: 3)),
        ),
        lead('Unscheduled Lead'),
        lead(
          'Legacy Reminder',
        ).copyWith(followUpAt: now.add(const Duration(days: 2))),
      ];
      final plan = Plan(
        id: 'sales',
        clientId: clients.first.id,
        type: PlanType.setup,
        name: 'Sales Tasks',
        price: 0,
        startDate: now,
        features: const [
          'Sales / Call: Call customer',
          'Sales / Meeting: Meet customer',
          'Sales / Proposal: Future proposal',
          'Sales / Call: No due time',
          'Sales / Call: Completed call',
          'Sales / Call: Archived call',
        ],
        completedFeatures: const ['Sales / Call: Completed call'],
        taskWorkflow: {
          'Sales / Call: Call customer': {
            'assignedTo': 'staff',
            'assignedToName': 'Sales Staff',
            'dueAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          },
          'Sales / Meeting: Meet customer': {'dueAt': now.toIso8601String()},
          'Sales / Proposal: Future proposal': {
            'dueAt': now.add(const Duration(days: 2)).toIso8601String(),
          },
          'Sales / Call: Archived call': {'isArchived': true},
        },
      );
      final profile = AppUser(
        uid: 'admin',
        email: '',
        name: 'Admin',
        isAdmin: true,
      );
      final planUpdates = StreamController<List<Plan>>();
      addTearDown(planUpdates.close);
      planUpdates.add([plan]);
      final container = ProviderContainer(
        overrides: [
          firebaseAuthServiceProvider.overrideWithValue(_TestAuthService()),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_TestUser(profile.uid)),
          ),
          firestoreServiceProvider.overrideWithValue(service),
          currentUserProfileProvider.overrideWith((ref) async => profile),
          allPlansStreamProvider.overrideWith((ref) => planUpdates.stream),
          clientsListProvider.overrideWith((ref) async => clients),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/admin/leads',
        routes: [
          GoRoute(
            path: '/admin/leads',
            builder: (_, _) => const ClientListScreen(),
          ),
          GoRoute(
            path: '/admin/sales-tasks',
            builder: (_, state) => SalesTasksScreen(
              customerId: state.uri.queryParameters['customer'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sales Pipeline'), findsNWidgets(2));
      expect(find.text('Sales Tasks'), findsOneWidget);
      expect(find.text('Overdue Lead'), findsOneWidget);
      expect(find.text('Unscheduled Lead'), findsOneWidget);
      expect(find.text('Legacy Reminder'), findsOneWidget);
      expect(find.text('Leads (2)'), findsOneWidget);
      expect(find.text('Follow Up (1)'), findsOneWidget);
      expect(find.text('Today & Overdue (2)'), findsNothing);
      expect(find.byTooltip('Add lead'), findsOneWidget);
      expect(find.byTooltip('Import / export leads'), findsOneWidget);
      await tester.tap(find.byTooltip('Create sales task').first);
      await tester.pumpAndSettle();
      final pipelineCreation = tester.widget<SalesRecordDialog>(
        find.byType(SalesRecordDialog),
      );
      expect(pipelineCreation.customerRecord, isTrue);
      expect(pipelineCreation.client.id, clients.first.id);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open sales tasks').first);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/admin/sales-tasks');
      expect(router.state.uri.queryParameters['customer'], clients.first.id);
      expect(find.text('All active (1)'), findsOneWidget);
      expect(find.text('Show all customers'), findsOneWidget);
      await tester.tap(find.text('Show all customers'));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters.containsKey('customer'), isFalse);
      await tester.tap(find.text('Today & Overdue (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Pipeline'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byTooltip('Add lead'), findsNothing);
      expect(find.text('Sales Tasks'), findsNWidgets(2));
      expect(find.textContaining('All leads'), findsNothing);
      expect(find.text('Overdue Lead'), findsOneWidget);
      expect(find.text('Unscheduled Lead'), findsNothing);
      expect(find.text('Legacy Reminder'), findsNothing);
      expect(find.textContaining('Registration:'), findsNothing);
      expect(find.textContaining('Created:'), findsNothing);
      expect(
        find.text('Customer stage: ${clients.first.stage.displayName}'),
        findsNothing,
      );
      expect(find.text('Salesperson'), findsNothing);
      expect(find.text('Open task'), findsNothing);
      expect(find.textContaining('Assignee:'), findsOneWidget);
      await tester.tap(find.text('Call customer'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesRecordDialog), findsOneWidget);
      expect(find.text('Customer details'), findsOneWidget);
      expect(find.text('Drafts'), findsNothing);
      expect(find.text('Draft link'), findsNothing);
      expect(find.text('Customer activity log'), findsNothing);
      expect(find.text('Preserved task history (6)'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overdue Lead').first);
      await tester.pumpAndSettle();
      expect(find.byType(SalesRecordDialog), findsOneWidget);
      expect(
        tester
            .widget<SalesRecordDialog>(find.byType(SalesRecordDialog))
            .initialTask!
            .plan
            .taskWorkflow['Sales / Call: Call customer']!['assignedTo'],
        'staff',
      );
      expect(find.text('Complete'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add lead'), findsNothing);
      expect(find.text('Today & Overdue (1)'), findsOneWidget);
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Unscheduled (0)'), findsOneWidget);
      expect(find.text('All active (2)'), findsOneWidget);
      expect(find.text('Completed (0)'), findsOneWidget);
      expect(find.text('Archived tasks (1)'), findsNothing);
      expect(find.text('Overdue Lead'), findsOneWidget);
      expect(find.text('Unscheduled Lead'), findsNothing);
      expect(find.text('Legacy Reminder'), findsNothing);
      await tester.tap(find.text('Open customer record'));
      await tester.pumpAndSettle();
      expect(find.text('Choose customer'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Search customers',
        ),
        'Unscheduled',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Overdue Lead'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Unscheduled Lead'));
      await tester.pumpAndSettle();
      final creation = tester.widget<SalesRecordDialog>(
        find.byType(SalesRecordDialog),
      );
      expect(creation.customerRecord, isTrue);
      expect(creation.client.id, 'Unscheduled Lead');
      expect(find.byKey(const ValueKey('create-task-assignee')), findsNothing);
      expect(service.createdPlans, isEmpty);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
      final reminder = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<bool> &&
            widget.decoration.labelText == 'Reminder',
      );
      await tester.ensureVisible(reminder);
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set date & time').last);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      final reminderNow = DateTime.now();
      final nextDue = DateTime(
        reminderNow.year,
        reminderNow.month,
        reminderNow.day + 1,
      );
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        MaterialLocalizations.of(
          tester.element(find.byType(DatePickerDialog)),
        ).formatCompactDate(nextDue),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save record'));
      await tester.pumpAndSettle();
      expect(service.createdPlans, isEmpty);
      expect(service.savedSalesRecords.last['stage'], ClientStage.click);
      expect(service.savedSalesRecords.last['doNotContact'], isFalse);
      final savedDue = service.savedSalesRecords.last['dueAt'] as DateTime;
      expect(DateUtils.dateOnly(savedDue), nextDue);
      expect(service.savedSalesRecords.last['reminderDays'], isNull);
      expect(service.savedSalesRecords.last['reminderTimeMinutes'], isNull);
      expect(service.subscriptions, 0);
      planUpdates.add([plan]);
      await tester.pumpAndSettle();
      expect(find.text('Unscheduled (0)'), findsOneWidget);
      expect(find.text('Today & Overdue (1)'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Call customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call customer'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesRecordDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-sales-stage')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButtonFormField<bool>),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Overdue Lead'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.textContaining('All active (')).data,
        'All active (3)',
      );
      await tester.tap(find.text('All active (3)'));
      await tester.pumpAndSettle();
      expect(find.text('All active (3)'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 844);
      for (final archived in [false, true]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ClientCard(
                  client: clients.first.copyWith(
                    stage: ClientStage.lost,
                    isArchived: archived,
                  ),
                  compactSales: true,
                  salesTasks: const [],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Delete lost lead'), findsOneWidget);
        expect(
          find.byTooltip(archived ? 'Restore lead' : 'Archive lead'),
          findsOneWidget,
        );
        expect(
          find.byIcon(
            archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          ),
          findsOneWidget,
        );
        expect(find.byTooltip('Lead actions'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'sales task creation links a lead without changing its delivery plan',
    (tester) async {
      final service = _TestFirestoreService();
      final profile = AppUser(
        uid: 'sales-staff',
        email: 'sales@example.com',
        name: 'Sales Staff',
        isAdmin: true,
      );
      final client = Client(
        id: 'lead-sales',
        name: 'Sales Lead',
        category: '',
        contactEmail: '',
        contactPhone: '9000000000',
        stage: ClientStage.click,
        createdDate: DateTime(2026, 10, 2),
      );
      final delivery = Plan(
        id: 'delivery',
        clientId: client.id,
        type: PlanType.setup,
        name: 'Delivery',
        price: 1000,
        features: const ['Content: Delivery'],
        startDate: DateTime(2026, 10, 1),
      );
      final container = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => profile),
          firestoreServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => CustomTaskDialog(
                        plans: [delivery],
                        clients: [client],
                        staff: [profile],
                        initialClientId: client.id,
                        salesOnly: true,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sales Lead'), findsOneWidget);
      expect(find.text('Leads'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'First sales call');
      await tester.ensureVisible(
        find.byKey(const ValueKey('create-task-assignee')),
      );
      await tester.tap(find.byKey(const ValueKey('create-task-assignee')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales Staff').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create task'));
      await tester.pumpAndSettle();
      expect(service.createdPlans, isEmpty);
      expect(
        find.text(
          'Sales tasks need a customer, assigned staff, and due date/time.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Set due date'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Set due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create task'));
      await tester.pumpAndSettle();
      final saved = service.createdPlans.single;
      expect(saved.name, 'Sales Tasks');
      expect(saved.clientId, client.id);
      expect(saved.price, 0);
      expect(saved.tasks.single.category, 'Sales / Call');
      expect(taskAssigneeId(saved, saved.tasks.single.feature), profile.uid);
      expect(taskDueAt(saved, saved.tasks.single.feature), isNotNull);
      expect(service.updatedPlans, isEmpty);
      expect(client.stage, ClientStage.click);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'profile HTTPS fallback preserves staff identity and panel restrictions',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'firestore.googleapis.com');
        expect(request.url.pathSegments.last, 'staff@example.com');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'fields': {
              'name': {'stringValue': 'Staff'},
              'email': {'stringValue': 'staff@example.com'},
              'isAdmin': {'booleanValue': true},
              'isStaff': {'booleanValue': true},
              'panels': {
                'arrayValue': {
                  'values': [
                    {'stringValue': 'chat'},
                    {'stringValue': 'unknown-panel'},
                  ],
                },
              },
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final service = _UnavailableProfileService(
        user: _TestUser('auth-uid', email: ' STAFF@example.com '),
        client: client,
      );
      final profile = await service.getUserProfile('auth-uid');
      expect(profile?.uid, 'staff@example.com');
      expect(profile?.isAdmin, isFalse);
      expect(profile?.canAccessPanel('chat'), isTrue);
      expect(profile?.canAccessPanel('users'), isFalse);
      expect(profile?.panels, ['chat']);
    },
  );

  test(
    'profile HTTPS fallback checks UID only after missing email profile',
    () async {
      final requestedIds = <String>[];
      final client = MockClient((request) async {
        final id = request.url.pathSegments.last;
        requestedIds.add(id);
        if (id == 'staff@example.com') return http.Response('{}', 404);
        return http.Response(
          jsonEncode({
            'fields': {
              'isAdmin': {'booleanValue': true},
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final service = _UnavailableProfileService(
        user: _TestUser('auth-uid', email: 'staff@example.com'),
        client: client,
      );
      final profile = await service.getUserProfile('auth-uid');
      expect(requestedIds, ['staff@example.com', 'auth-uid']);
      expect(profile?.uid, 'auth-uid');
      expect(profile?.isAdmin, isTrue);
    },
  );

  test(
    'profile HTTPS denial does not fall through to the admin UID profile',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response('{}', 403);
      });
      addTearDown(client.close);
      final service = _UnavailableProfileService(
        user: _TestUser('auth-uid', email: 'staff@example.com'),
        client: client,
      );
      await expectLater(
        service.getUserProfile('auth-uid'),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      expect(requests, 1);
    },
  );

  test(
    'profile automatically recovers from timeout and connection errors',
    () async {
      final service = _TestAuthService(
        profileErrors: {
          'staff': [
            TimeoutException('Temporary profile timeout'),
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          ],
        },
      );
      final states = <AsyncValue<AppUser?>>[];
      final container = ProviderContainer(
        overrides: [
          firebaseAuthServiceProvider.overrideWithValue(service),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_TestUser('staff')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      container.listen(
        currentUserProfileProvider,
        (previous, next) => states.add(next),
      );
      final profile = await container.read(currentUserProfileProvider.future);
      expect(profile?.uid, 'staff');
      expect(service.requestedProfiles, ['staff', 'staff', 'staff']);
      expect(states.any((state) => state.hasError), isFalse);
    },
  );

  test(
    'web profile HTTPS reads bypass a stalled SDK and preserve access',
    () async {
      final requestedIds = <String>[];
      final client = MockClient((request) async {
        final id = request.url.pathSegments.last;
        requestedIds.add(id);
        expect(request.headers['Authorization'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'fields': {
              'isAdmin': {'booleanValue': true},
              'panels': {
                'arrayValue': {
                  'values': [
                    {'stringValue': 'myTasks'},
                  ],
                },
              },
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final service = _DirectHttpProfileService(
        user: _TestUser('auth-uid', email: 'staff@example.com'),
        client: client,
      );
      final profile = await service.getUserProfile('auth-uid');
      expect(service.sdkReads, 0);
      expect(requestedIds, ['staff@example.com']);
      expect(profile?.uid, 'staff@example.com');
      expect(profile?.isAdmin, isFalse);
      expect(profile?.canAccessPanel('myTasks'), isTrue);
      expect(profile?.canAccessPanel('users'), isFalse);
    },
  );

  test(
    'web profile HTTPS reads fall through only for a missing email profile',
    () async {
      for (final status in [404, 403, 503]) {
        final requestedIds = <String>[];
        final client = MockClient((request) async {
          final id = request.url.pathSegments.last;
          requestedIds.add(id);
          return http.Response(
            id == 'auth-uid'
                ? '{"fields":{"isAdmin":{"booleanValue":true}}}'
                : '{}',
            id == 'auth-uid' ? 200 : status,
          );
        });
        addTearDown(client.close);
        final service = _DirectHttpProfileService(
          user: _TestUser('auth-uid', email: 'staff@example.com'),
          client: client,
        );
        if (status == 404) {
          final profile = await service.getUserProfile('auth-uid');
          expect(profile?.isAdmin, isTrue);
          expect(requestedIds, ['staff@example.com', 'auth-uid']);
        } else {
          await expectLater(
            service.getUserProfile('auth-uid'),
            throwsA(
              isA<FirebaseException>().having(
                (error) => error.code,
                'code',
                status == 403 ? 'permission-denied' : 'unavailable',
              ),
            ),
          );
          expect(requestedIds, ['staff@example.com']);
        }
        expect(service.sdkReads, 0);
      }
    },
  );

  testWidgets('profile loading stops after three transient failures', (
    tester,
  ) async {
    final service = _TestAuthService(
      profileErrors: {
        'staff': List.generate(
          4,
          (_) =>
              FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        firebaseAuthServiceProvider.overrideWithValue(service),
        authStateProvider.overrideWith(
          (ref) => Stream.value(_TestUser('staff')),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authStateProvider, (previous, next) {});
    await tester.pump();
    final result = expectLater(
      container.read(currentUserProfileProvider.future),
      throwsA(isA<FirebaseException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    await result;
    expect(service.requestedProfiles, ['staff', 'staff', 'staff']);
    expect(container.read(currentUserProfileProvider).hasError, isTrue);
    await tester.pump(const Duration(seconds: 8));
    expect(service.requestedProfiles.length, 3);
  });

  testWidgets('profile loading has a twenty second overall limit', (
    tester,
  ) async {
    final service = _PendingProfileService();
    final container = ProviderContainer(
      overrides: [
        firebaseAuthServiceProvider.overrideWithValue(service),
        authStateProvider.overrideWith(
          (ref) => Stream.value(_TestUser('staff')),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authStateProvider, (previous, next) {});
    await tester.pump();
    final result = expectLater(
      container.read(currentUserProfileProvider.future),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 19));
    expect(container.read(currentUserProfileProvider).isLoading, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await result;
    expect(container.read(currentUserProfileProvider).hasError, isTrue);
    service.pending.complete(
      AppUser(uid: 'staff', email: '', name: 'Staff', isAdmin: true),
    );
    await tester.pump();
    expect(container.read(currentUserProfileProvider).hasError, isTrue);
    expect(service.requestedProfiles, ['staff']);
  });

  testWidgets('profile auth guard offers retry after a loading failure', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_TestUser('staff')),
          ),
          currentUserProfileProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw TimeoutException('Profile unavailable');
            return null;
          }),
        ],
        child: const MaterialApp(home: AuthGuardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Error checking staff access:'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.textContaining('Staff access required.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('profile retries stop when the signed-in account changes', () async {
    final authChanges = StreamController<User?>();
    addTearDown(authChanges.close);
    final service = _TestAuthService(
      profileErrors: {
        'old-staff': [
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ],
      },
    );
    final container = ProviderContainer(
      overrides: [
        firebaseAuthServiceProvider.overrideWithValue(service),
        authStateProvider.overrideWith((ref) => authChanges.stream),
      ],
    );
    addTearDown(container.dispose);
    container.listen(currentUserProfileProvider, (previous, next) {});
    authChanges.add(_TestUser('old-staff'));
    await container.read(authStateProvider.future);
    container.read(currentUserProfileProvider);
    await Future<void>.delayed(Duration.zero);
    expect(service.requestedProfiles, ['old-staff']);
    authChanges.add(_TestUser('new-staff'));
    await Future<void>.delayed(Duration.zero);
    expect(
      (await container.read(currentUserProfileProvider.future))?.uid,
      'new-staff',
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(service.requestedProfiles, ['old-staff', 'new-staff']);
  });

  test(
    'profile permission failures do not grant access or retry indefinitely',
    () async {
      final service = _TestAuthService(
        profileErrors: {
          'staff': [
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [
          firebaseAuthServiceProvider.overrideWithValue(service),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_TestUser('staff')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      await expectLater(
        container.read(currentUserProfileProvider.future),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      expect(service.requestedProfiles, ['staff']);
      expect(container.read(currentUserProfileProvider).hasError, isTrue);
    },
  );

  testWidgets('completed period selector filters tasks and opens custom dates', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      initialLocation: '/admin/completed-tasks',
      routes: [
        GoRoute(
          path: '/admin/completed-tasks',
          builder: (context, state) => const CompletedTasksScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    final today = DateUtils.dateOnly(DateTime.now());
    const todayFeature = 'Vision & Plan: Completed today';
    const olderFeature = 'Vision & Plan: Completed earlier';
    const undatedFeature = 'Vision & Plan: Completed without a date';
    final plan = Plan(
      id: 'completed-plan',
      clientId: 'client-1',
      type: PlanType.setup,
      name: 'Plan',
      price: 0,
      startDate: today,
      features: const [todayFeature, olderFeature, undatedFeature],
      taskWorkflow: {
        todayFeature: {
          'status': 'completed',
          'completedAt': today.toIso8601String(),
        },
        olderFeature: {
          'status': 'completed',
          'completedAt': today
              .subtract(const Duration(days: 40))
              .toIso8601String(),
        },
        undatedFeature: {'status': 'completed'},
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthServiceProvider.overrideWithValue(_TestAuthService()),
          currentUserProfileProvider.overrideWith(
            (ref) async => AppUser(
              uid: 'admin',
              email: 'admin@example.com',
              name: 'Admin',
              isAdmin: true,
            ),
          ),
          allPlansStreamProvider.overrideWith((ref) => Stream.value([plan])),
          clientsListProvider.overrideWith((ref) async => <Client>[]),
          firestoreServiceProvider.overrideWithValue(_TestFirestoreService()),
          allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final selector = find.byKey(const ValueKey('completed-period-selector'));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('completed-period-controls')))
          .height,
      lessThanOrEqualTo(48),
    );
    final navigation = find.byKey(
      const ValueKey('completed-period-navigation'),
    );
    final summaryTitle = find.textContaining(RegExp(r'^Completed Tasks  \d+$'));
    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Search tasks',
    );
    expect(
      tester.getTopLeft(selector).dx,
      greaterThan(tester.getTopRight(summaryTitle).dx),
    );
    expect(
      tester.getTopLeft(searchField).dy,
      greaterThan(tester.getBottomLeft(navigation).dy),
    );
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'all',
    );
    expect(find.text('Completed today'), findsOneWidget);
    expect(find.text('Completed earlier'), findsOneWidget);
    expect(find.text('Completed without a date'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: navigation,
        matching: find.text(
          MaterialLocalizations.of(
            tester.element(selector),
          ).formatShortDate(today),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Completed today'), findsOneWidget);
    expect(find.text('Completed earlier'), findsNothing);
    expect(find.text('Completed without a date'), findsNothing);
    expect(
      find.descendant(
        of: navigation,
        matching: find.byTooltip('Previous period'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(find.text('Completed today'), findsNothing);
    await tester.tap(find.byTooltip('Next period'));
    await tester.pumpAndSettle();
    expect(find.text('Completed today'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    final weekStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));
    final localizations = MaterialLocalizations.of(tester.element(selector));
    expect(
      find.text(
        '${localizations.formatShortMonthDay(weekStart)} - ${localizations.formatShortMonthDay(weekEnd)}',
      ),
      findsOneWidget,
    );
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'week',
    );
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'month',
    );
    expect(find.text(localizations.formatMonthYear(today)), findsOneWidget);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    final popup = find.byKey(const ValueKey('completed-date-popup'));
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getSize(popup).width, lessThan(screenSize.width));
    expect(tester.getSize(popup).height, lessThan(screenSize.height));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'month',
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(selector).dy,
      greaterThan(tester.getBottomLeft(summaryTitle).dy),
    );
    expect(
      tester.getTopLeft(searchField).dy,
      greaterThan(tester.getBottomLeft(navigation).dy),
    );
    await tester.ensureVisible(find.text('Week'));
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Previous period'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Select dates'));
    await tester.tap(find.byTooltip('Select dates'));
    await tester.pumpAndSettle();
    expect(tester.getSize(popup).width, lessThanOrEqualTo(358));
    expect(tester.getSize(popup).height, lessThanOrEqualTo(600));
    await tester.tap(find.text(localizations.saveButtonLabel));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'custom',
    );
    expect(find.text('Completed today'), findsOneWidget);
    await tester.enterText(searchField, 'today');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Previous period'));
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(find.text('Completed today'), findsNothing);
    final clearFilters = find.widgetWithText(TextButton, 'Clear filters');
    await tester.ensureVisible(clearFilters);
    await tester.tap(clearFilters);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'all',
    );
    expect(tester.widget<TextField>(searchField).controller!.text, isEmpty);
    expect(find.text('Completed today'), findsOneWidget);
    expect(find.text('Completed earlier'), findsOneWidget);
    expect(find.text('Completed without a date'), findsOneWidget);
    expect(clearFilters, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scenario in [
    (
      name: 'admin personal view',
      admin: true,
      tasksAccess: true,
      personal: true,
    ),
    (
      name: 'staff without Assign Tasks access',
      admin: false,
      tasksAccess: false,
      personal: false,
    ),
    (
      name: 'staff with Assign Tasks access',
      admin: false,
      tasksAccess: true,
      personal: false,
    ),
    (
      name: 'admin assignment view',
      admin: true,
      tasksAccess: false,
      personal: false,
    ),
  ]) {
    testWidgets('completion controls: ${scenario.name}', (tester) async {
      final service = _TestFirestoreService();
      final profile = AppUser(
        uid: 'staff@example.com',
        email: 'staff@example.com',
        name: 'Staff',
        isAdmin: scenario.admin,
        isStaff: true,
        panels: scenario.tasksAccess ? ['tasks', 'myTasks'] : ['myTasks'],
      );
      const feature = 'Vision & Plan: Assigned task';
      final plan = Plan(
        id: 'plan-1',
        clientId: 'client-1',
        type: PlanType.setup,
        name: 'Plan',
        price: 0,
        startDate: DateTime(2024),
        features: const [feature],
        taskWorkflow: {
          feature: {'assignedTo': profile.uid, 'status': 'assigned'},
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) async => profile),
            currentStaffIdsProvider.overrideWith((ref) => [profile.uid]),
            firestoreServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => TaskWorkflowDialog(
                      task: TaskItem(rawFeature: feature, plan: plan),
                      clientName: 'Client',
                      ref: ref,
                      staff: [profile],
                      lockedAssigneeId: scenario.personal ? profile.uid : null,
                    ),
                  ),
                  child: const Text('Open task'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open task'));
      await tester.pumpAndSettle();
      final canComplete = !scenario.personal && profile.canAccessPanel('tasks');
      expect(find.byType(DropdownButtonFormField<TaskStatus>), findsNothing);
      final completeButton = find.widgetWithText(OutlinedButton, 'Complete');
      expect(completeButton, canComplete ? findsOneWidget : findsNothing);
      if (canComplete) {
        await tester.tap(completeButton);
      } else {
        await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      }
      await tester.pumpAndSettle();
      expect(service.updatedPlans, hasLength(1));
      expect(
        taskStatus(service.updatedPlans.single, feature),
        canComplete ? TaskStatus.completed : TaskStatus.assigned,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final selfAssignOnly in [false, true]) {
    testWidgets(
      'task client dropdown only includes current Sale and Retain clients: self=$selfAssignOnly',
      (tester) async {
        final service = _TestFirestoreService();
        final profile = AppUser(
          uid: 'staff',
          email: 'staff@example.com',
          name: 'Staff',
          isAdmin: !selfAssignOnly,
          isStaff: true,
        );
        final clients = [
          for (final stage in ClientStage.values)
            for (final archived in [false, true])
              Client(
                id: '${stage.name}-$archived',
                name:
                    '${archived ? 'Archived' : 'Current'} ${stage.displayName} ${stage.name}',
                category: '',
                contactEmail: '',
                contactPhone: '',
                stage: stage,
                isArchived: archived,
                createdDate: DateTime(2026, 10, 3),
              ),
        ];
        final existingPlans = [
          for (final client in clients)
            if (client.stage != ClientStage.client &&
                client.stage != ClientStage.retain)
              Plan(
                id: 'plan-${client.id}',
                clientId: client.id,
                type: PlanType.setup,
                name: 'Existing delivery plan',
                price: 100,
                features: const ['Content: Existing work'],
                startDate: DateTime(2026, 10, 3),
              ),
        ];
        final container = ProviderContainer(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) async => profile),
            currentStaffIdsProvider.overrideWithValue([profile.uid]),
            firestoreServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: CustomTaskDialog(
                  plans: existingPlans,
                  clients: clients,
                  staff: [profile],
                  selfAssignOnly: selfAssignOnly,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final clientField = find.byKey(const ValueKey('create-task-client'));
        void expectEligibleClients() {
          final dropdown = tester.widget<DropdownButton<String>>(
            find.descendant(
              of: clientField,
              matching: find.byType(DropdownButton<String>),
            ),
          );
          expect(dropdown.items!.map((item) => item.value), [
            '__internal_practice__',
            'refer-false',
            'retain-false',
            'client-false',
          ]);
        }

        expectEligibleClients();
        await tester.tap(clientField);
        await tester.pumpAndSettle();
        final saleClient = clients.firstWhere(
          (client) => client.id == 'client-false',
        );
        await tester.tap(find.text(saleClient.name).last);
        await tester.pumpAndSettle();
        for (final category in ['Software', 'Sales', 'Vision & Plan']) {
          await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.text(category).last);
          await tester.pumpAndSettle();
          expectEligibleClients();
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(clientField)
                .initialValue,
            saleClient.id,
          );
        }
        await tester.enterText(find.byType(TextField).first, 'Customer task');
        await tester.enterText(
          find.byType(TextField).last,
          'Customer instructions',
        );
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Create task'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create task'));
        await tester.pumpAndSettle();
        expect(service.createdPlans.single.clientId, saleClient.id);
        expect(service.updatedPlans, isEmpty);
        if (selfAssignOnly) {
          final plan = service.createdPlans.single;
          expect(taskAssigneeId(plan, plan.features.single), profile.uid);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final staffOnly in [false, true]) {
    testWidgets(
      staffOnly
          ? 'staff without management access creates a separate self-assigned task'
          : 'personal task creation locks assignment to the current profile',
      (tester) async {
        final service = _TestFirestoreService();
        final profile = AppUser(
          uid: 'staff@example.com',
          email: 'staff@example.com',
          name: 'Current Staff',
          isAdmin: !staffOnly,
          isStaff: staffOnly,
        );
        final sharedPractice = Plan(
          id: 'internal-practice-tasks',
          clientId: '__internal_practice__',
          type: PlanType.setup,
          name: 'Practice (Internal)',
          price: 0,
          startDate: DateTime.now(),
          features: const ['Content: Existing task'],
          taskWorkflow: const {
            'Content: Existing task': {'assignedTo': 'other-staff'},
          },
        );
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                _TestUser('staff-auth-uid', email: profile.email),
              ),
            ),
            currentUserProfileProvider.overrideWith((ref) async => profile),
            firestoreServiceProvider.overrideWithValue(service),
            allPlansStreamProvider.overrideWith(
              (ref) => Stream.value([if (staffOnly) sharedPractice]),
            ),
            clientsListProvider.overrideWith((ref) async => <Client>[]),
            allUsersProvider.overrideWith(
              (ref) => Stream.value([
                profile,
                AppUser(
                  uid: 'other-staff',
                  email: 'other@example.com',
                  name: 'Other Staff',
                  isAdmin: false,
                ),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MyAssignedTasksScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Create my task'));
        await tester.pumpAndSettle();
        expect(find.text('Current Staff'), findsWidgets);
        expect(find.text('Other Staff'), findsNothing);
        expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));

        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Practice (Internal)').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'My own task');
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vision & Plan').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Personal follow-up',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create task'));
        await tester.pumpAndSettle();

        expect(service.createdPlans, hasLength(1));
        final plan = service.createdPlans.single;
        expect(
          plan.id,
          staffOnly
              ? isNot('internal-practice-tasks')
              : 'internal-practice-tasks',
        );
        expect(plan.clientId, '__internal_practice__');
        expect(plan.tasks.single.title, 'My own task');
        expect(taskAssigneeId(plan, plan.tasks.single.feature), profile.uid);
        expect(service.updatedPlans, isEmpty);
        expect(plan.price, 0);
        expect(plan.features, hasLength(1));
        expect(find.byType(CustomTaskDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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

  for (final completedOnly in [false, true]) {
    testWidgets(
      'personal task client names cover non-sales tasks and practice: completed=$completedOnly',
      (tester) async {
        final clients = [
          for (final id in ['first', 'second'])
            Client(
              id: id,
              name: '$id Customer',
              category: '',
              contactEmail: '',
              contactPhone: '',
              stage: ClientStage.client,
              createdDate: DateTime(2026, 10, 3),
            ),
        ];
        Plan taskPlan(String id, String clientId, {bool archived = false}) {
          final feature = 'Software / App: $id work';
          return Plan(
            id: id,
            clientId: clientId,
            type: PlanType.setup,
            name: 'Custom Tasks',
            price: 0,
            startDate: DateTime(2026, 10, 3),
            features: [feature],
            taskWorkflow: {
              feature: {
                'assignedTo': 'staff',
                if (completedOnly) 'status': 'completed',
                if (archived) 'isArchived': true,
              },
            },
          );
        }

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            firestoreServiceProvider.overrideWithValue(_TestFirestoreService()),
            currentStaffIdsProvider.overrideWithValue(['staff']),
            currentUserProfileProvider.overrideWith(
              (ref) async => AppUser(
                uid: 'staff',
                email: 'staff@example.com',
                name: 'Staff',
                isAdmin: false,
                isStaff: true,
              ),
            ),
            allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
            clientsListProvider.overrideWith((ref) async => clients),
            allPlansStreamProvider.overrideWith(
              (ref) => Stream.value([
                taskPlan('first', 'first'),
                taskPlan('second', 'second'),
                taskPlan('practice', '__internal_practice__'),
                taskPlan('missing', 'deleted-client'),
                if (!completedOnly)
                  taskPlan('archived', 'second', archived: true),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: completedOnly
                  ? const MyCompletedTasksScreen()
                  : const MyAssignedTasksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Client: first Customer'), findsOneWidget);
        expect(find.textContaining('Client: second Customer'), findsOneWidget);
        expect(
          find.textContaining('Client: Practice (Internal)'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.textContaining('Client: No client linked'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.textContaining('Client: No client linked'), findsOneWidget);
        expect(find.textContaining('Client: My task'), findsNothing);
        if (!completedOnly) {
          await tester.scrollUntilVisible(
            find.text('Archived (1)'),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text('Archived (1)'));
          await tester.pumpAndSettle();
          final archivedRow = tester.widget<TaskRow>(
            find.ancestor(
              of: find.text('archived work'),
              matching: find.byType(TaskRow),
            ),
          );
          expect(archivedRow.clientName, 'second Customer');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'personal task client loading errors offer retry: completed=$completedOnly',
      (tester) async {
        final pendingClients = Completer<List<Client>>();
        var attempts = 0;
        const feature = 'Content / Content: Customer work';
        final client = Client(
          id: 'customer',
          name: 'Recovered Customer',
          category: '',
          contactEmail: '',
          contactPhone: '',
          stage: ClientStage.client,
          createdDate: DateTime(2026, 10, 3),
        );
        final container = ProviderContainer(
          overrides: [
            currentStaffIdsProvider.overrideWithValue(['staff']),
            currentUserProfileProvider.overrideWith(
              (ref) async => AppUser(
                uid: 'staff',
                email: 'staff@example.com',
                name: 'Staff',
                isAdmin: false,
                isStaff: true,
              ),
            ),
            allUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
            clientsListProvider.overrideWith((ref) {
              attempts++;
              return attempts == 1
                  ? pendingClients.future
                  : Future.value([client]);
            }),
            allPlansStreamProvider.overrideWith(
              (ref) => Stream.value([
                Plan(
                  id: 'plan',
                  clientId: client.id,
                  type: PlanType.setup,
                  name: 'Custom Tasks',
                  price: 0,
                  startDate: DateTime(2026, 10, 3),
                  features: const [feature],
                  taskWorkflow: {
                    feature: {
                      'assignedTo': 'staff',
                      if (completedOnly) 'status': 'completed',
                    },
                  },
                ),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: completedOnly
                  ? const MyCompletedTasksScreen()
                  : const MyAssignedTasksScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(LoadingWidget), findsOneWidget);
        expect(find.byType(TaskRow), findsNothing);
        pendingClients.completeError(StateError('Client fetch failed'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Error loading task clients:'),
          findsOneWidget,
        );
        expect(find.textContaining('Client fetch failed'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(
          find.textContaining('Client: Recovered Customer'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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
        clientsListProvider.overrideWith((ref) async => <Client>[]),
        firestoreServiceProvider.overrideWithValue(_TestFirestoreService()),
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
        'Software: Older completed task',
        'Vision & Plan: Undated completed task',
      ],
      taskWorkflow: {
        'Content: Legacy task': {'assignedTo': 'staff@example.com'},
        'Content: New task': {'assignedTo': 'staff-auth-uid'},
        'Content: Other staff task': {'assignedTo': 'other-staff'},
        'Content: Completed task': {
          'assignedTo': 'staff@example.com',
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
        },
        'Software: Older completed task': {
          'assignedTo': 'staff@example.com',
          'status': 'completed',
          'completedAt': DateTime.now()
              .subtract(const Duration(days: 40))
              .toIso8601String(),
        },
        'Vision & Plan: Undated completed task': {
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
    expect(find.text('Older completed task'), findsOneWidget);
    expect(find.text('Undated completed task'), findsOneWidget);
    final selector = find.byKey(const ValueKey('completed-period-selector'));
    final controls = find.byKey(const ValueKey('completed-period-controls'));
    final clearFilters = find.widgetWithText(TextButton, 'Clear filters');
    expect(tester.widget<TextButton>(clearFilters).onPressed, isNull);
    expect(tester.getSize(controls).height, 48);
    expect(find.text('Completed period'), findsNothing);
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'all',
    );
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Older completed task'), findsNothing);
    expect(find.text('Undated completed task'), findsNothing);
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(find.text('Completed task'), findsNothing);
    await tester.tap(find.byTooltip('Next period'));
    await tester.pumpAndSettle();
    expect(find.text('Completed task'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    final popup = find.byKey(const ValueKey('completed-date-popup'));
    expect(tester.getSize(popup).width, lessThanOrEqualTo(480));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'week',
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();
    expect(tester.getSize(controls).height, 48);
    await tester.tap(find.byTooltip('Select dates'));
    await tester.pumpAndSettle();
    expect(tester.getSize(popup).width, lessThanOrEqualTo(358));
    await tester.tap(
      find.text(
        MaterialLocalizations.of(tester.element(popup)).saveButtonLabel,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'custom',
    );
    expect(find.text('Completed task'), findsOneWidget);
    final categoryChip = find.byWidgetPredicate(
      (widget) =>
          widget is FilterChip &&
          widget.label is Text &&
          ((widget.label as Text).data ?? '').startsWith('Content'),
    );
    await tester.ensureVisible(categoryChip);
    await tester.tap(categoryChip);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(categoryChip).selected, isTrue);
    await tester.ensureVisible(find.byTooltip('Previous period'));
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(find.text('Completed task'), findsNothing);
    await tester.ensureVisible(clearFilters);
    await tester.tap(clearFilters);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<SegmentedButton>(selector).selected.single as Enum).name,
      'all',
    );
    expect(tester.widget<FilterChip>(categoryChip).selected, isFalse);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'All (3)'))
          .selected,
      isTrue,
    );
    expect(find.text('Completed task'), findsOneWidget);
    expect(find.text('Older completed task'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Undated completed task'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Undated completed task'), findsOneWidget);
    await tester.ensureVisible(clearFilters);
    expect(tester.widget<TextButton>(clearFilters).onPressed, isNull);
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
