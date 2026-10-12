import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/tasks/plan_changes.dart';
import 'package:tulasisolutionssite/core/tasks/task_workflow.dart';
import 'package:tulasisolutionssite/core/tasks/sales_record_options.dart';
import 'package:tulasisolutionssite/features/admin/tasks/customer_sales_record_dialog.dart';

final _actor = AppUser(
  uid: 'admin',
  email: '',
  name: 'Bharathi',
  isAdmin: true,
);

class _BoxingFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    try {
      return await super.runTransaction(
        handler,
        timeout: timeout,
        maxAttempts: maxAttempts,
      );
    } catch (_) {
      throw StateError('Dart exception thrown from converted Future.');
    }
  }
}

Client _client() => Client(
  id: 'customer',
  name: 'Learning Centre',
  category: 'Education',
  contactPhone: '',
  contactEmail: '',
  stage: ClientStage.click,
  createdDate: DateTime(2026),
  salesContacts: const [
    {
      'id': 'old',
      'method': 'Call',
      'outcome': 'Interested',
      'notes': 'Original contact',
    },
  ],
);
Plan _plan() => Plan(
  id: 'sales',
  clientId: 'customer',
  type: PlanType.setup,
  name: 'Sales Tasks',
  price: 0,
  startDate: DateTime(2026),
  features: const [
    'Sales / Call: First call',
    'Sales / Meeting: Later meeting',
  ],
  taskWorkflow: {
    'Sales / Call: First call': {
      'assignedTo': 'admin',
      'status': 'assigned',
      'dueAt': DateTime(2026, 10, 1).toIso8601String(),
      'internalNotes': 'Call notes',
    },
    'Sales / Meeting: Later meeting': {
      'assignedTo': 'staff',
      'status': 'assigned',
      'dueAt': DateTime(2026, 10, 20).toIso8601String(),
      'internalNotes': 'Meeting notes',
    },
  },
);

Future<void> _openRecord(
  WidgetTester tester,
  Client client,
  FirestoreService service, {
  List<Plan> plans = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProfileProvider.overrideWith((ref) async => _actor),
        firestoreServiceProvider.overrideWithValue(service),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    CustomerSalesRecordDialog(client: client, plans: plans),
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
}

Future<void> _choose<T>(
  WidgetTester tester,
  String label,
  String choice,
) async {
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<T> &&
        widget.decoration.labelText == label,
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  final menu = find.byType(Scrollable).last;
  tester.state<ScrollableState>(menu).position.jumpTo(0);
  await tester.pumpAndSettle();
  final option = find.descendant(of: menu, matching: find.text(choice));
  await tester.scrollUntilVisible(option, 200, scrollable: menu);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Future<void> _pickReminder(
  WidgetTester tester,
  DateTime due, {
  bool cancelTime = false,
}) async {
  final reminder = find.byKey(const ValueKey('customer-sales-reminder'));
  if (reminder.evaluate().isEmpty) {
    await _choose<bool>(tester, 'Reminder', 'Set date & time');
  } else {
    await tester.ensureVisible(reminder);
    await tester.tap(reminder);
  }
  await tester.pumpAndSettle();
  expect(find.byType(CalendarDatePicker), findsOneWidget);
  final localizations = MaterialLocalizations.of(
    tester.element(find.byType(DatePickerDialog)),
  );
  await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    ),
    localizations.formatCompactDate(due),
  );
  await tester.tap(find.text(localizations.okButtonLabel));
  await tester.pumpAndSettle();
  expect(find.byType(TimePickerDialog), findsOneWidget);
  if (cancelTime) {
    await tester.tap(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text(localizations.cancelButtonLabel),
      ),
    );
    await tester.pumpAndSettle();
    return;
  }
  await tester.tap(find.byTooltip(localizations.inputTimeModeButtonLabel));
  await tester.pumpAndSettle();
  final inputs = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  final period = find.text(
    due.hour < 12
        ? localizations.anteMeridiemAbbreviation
        : localizations.postMeridiemAbbreviation,
  );
  final hour = period.evaluate().isEmpty
      ? due.hour
      : (due.hour % 12 == 0 ? 12 : due.hour % 12);
  await tester.enterText(inputs.at(0), '$hour');
  await tester.enterText(inputs.at(1), '${due.minute}');
  if (period.evaluate().isNotEmpty) {
    await tester.tap(period.last);
  }
  await tester.tap(find.text(localizations.okButtonLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Sales notes load, save, reopen and clear while cancellation preserves stored notes',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final client = _client().copyWith(
        notes: 'Customer background',
        followUpNotes: 'Legacy reminder note',
        salesRecord: {'notes': 'Original sales note'},
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final service = FirestoreService(firestore: db);
      final field = find.byKey(const ValueKey('customer-sales-notes'));
      await _openRecord(tester, client, service);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Original sales note',
      );
      await tester.enterText(
        field,
        '  Pricing discussed\nSend revised estimate  ',
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      var saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(
        saved.salesRecord['notes'],
        'Pricing discussed\nSend revised estimate',
      );
      expect(saved.salesRecord['legacyNotes'], contains('Original sales note'));
      expect(saved.notes, 'Customer background');
      expect(saved.followUpNotes, 'Legacy reminder note');
      final log = (await service.salesActivity(client.id).first).single;
      expect(log['notes'], 'Pricing discussed\nSend revised estimate');
      expect(log['previousNotes'], 'Original sales note');
      expect(log['recordedByName'], 'Bharathi');
      await _openRecord(tester, saved, service);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Pricing discussed\nSend revised estimate',
      );
      await tester.enterText(field, 'Unsaved edit');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(
        saved.salesRecord['notes'],
        'Pricing discussed\nSend revised estimate',
      );
      expect(await service.salesActivity(client.id).first, hasLength(1));
      await _openRecord(tester, saved, service);
      await tester.enterText(field, '');
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesRecord['notes'], isEmpty);
      expect(
        saved.salesRecord['legacyNotes'],
        contains('Pricing discussed\nSend revised estimate'),
      );
      await _openRecord(tester, saved, service);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.text('Previous sales notes (read-only)'), findsNothing);
      expect(find.text('Customer activity log'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'A concurrent note edit cannot be overwritten even without a revision change',
    () async {
      final db = FakeFirebaseFirestore();
      final client = _client().copyWith(
        salesRecord: {'revision': 'same', 'notes': 'Original note'},
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      await db.collection('clients').doc(client.id).update({
        'salesRecord': {...client.salesRecord, 'notes': 'Another staff edit'},
      });
      final service = FirestoreService(firestore: db);
      await expectLater(
        service.saveCustomerSalesUpdate(
          client: client,
          actor: _actor,
          stage: client.stage,
          progress: null,
          dueAt: null,
          doNotContact: false,
          notes: 'My edit',
        ),
        throwsA(isA<PlanSaveConflict>()),
      );
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesRecord['notes'], 'Another staff edit');
      expect(await service.salesActivity(client.id).first, isEmpty);
    },
  );

  testWidgets(
    'Each stage offers only its short update list and two reminder choices',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final client = _client();
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      await _openRecord(tester, client, FirestoreService(firestore: db));
      const expected = {
        ClientStage.click: [
          'Not contacted',
          'No response',
          'Interested',
          'Not suitable',
        ],
        ClientStage.register: [
          'Discussion pending',
          'Details sent',
          'Proposal sent',
          'Awaiting response',
        ],
        ClientStage.consult: [
          'No response',
          'Considering',
          'Changes requested',
          'Ready to proceed',
          'Not interested',
        ],
        ClientStage.client: [
          'Confirmed',
          'Awaiting payment',
          'Onboarding pending',
          'Onboarding complete',
        ],
        ClientStage.retain: [
          'Check-in pending',
          'Satisfied',
          'Needs help',
          'Renewal pending',
          'Renewed',
          'Not renewing',
        ],
        ClientStage.refer: [
          'Not asked',
          'Referral requested',
          'Referral promised',
          'Referral received',
          'Thanked',
        ],
        ClientStage.lost: [
          'Not interested',
          'Not suitable',
          'Cancelled',
          'Duplicate',
          'Invalid contact',
        ],
      };
      for (final entry in expected.entries) {
        await _choose<ClientStage>(tester, 'Main stage', entry.key.displayName);
        final updateFinder = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == 'Update',
        );
        final update = tester.widget<DropdownButtonFormField<String>>(
          updateFinder,
        );
        final dropdown = tester.widget<DropdownButton<String>>(
          find.descendant(
            of: updateFinder,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        expect(dropdown.items!.map((item) => item.value), entry.value);
        expect(dropdown.items!.length, lessThanOrEqualTo(6));
        expect(update.initialValue, isNull);
        await _choose<String>(tester, 'Update', entry.value.first);
      }
      final reminder = tester.widget<DropdownButtonFormField<bool>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<bool> &&
              widget.decoration.labelText == 'Reminder',
        ),
      );
      final reminderDropdown = tester.widget<DropdownButton<bool>>(
        find.byType(DropdownButton<bool>),
      );
      expect(reminderDropdown.items!.map((item) => (item.child as Text).data), [
        'No reminder',
        'Set date & time',
      ]);
      expect(reminder.onChanged, isNull);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.stage, ClientStage.lost);
      expect(saved.salesProgress, 'Not interested');
      expect(saved.followUpAt, isNull);
      expect(saved.salesRecord['status'], 'completed');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Simple updates preserve legacy history, notes, assignees and completed tasks',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      final client = _client().copyWith(
        notes: 'Customer notes',
        followUpNotes: 'Reminder notes',
        salesProgress: 'Qualified',
        salesRecord: {
          'title': 'Previous call',
          'action': 'Call',
          'status': 'completed',
          'notes': 'Sales notes',
          'assignedTo': 'staff',
          'assignedToName': 'Staff',
          'outcome': 'Connected',
          'customerResponse': 'Interested',
        },
      );
      final plan = _plan();
      await db.collection('clients').doc(client.id).set({
        ...client.toFirestore(),
        'salesContacts': client.salesContacts,
      });
      await db.collection('plans').doc(plan.id).set(plan.toFirestore());
      final originalPlan = (await db.collection('plans').doc(plan.id).get())
          .data();
      Future<void> save(Client baseline, {String? progress, DateTime? due}) =>
          service.saveCustomerSalesUpdate(
            client: baseline,
            actor: _actor,
            stage: baseline.stage,
            progress: progress,
            dueAt: due,
            doNotContact: false,
          );
      await save(client);
      var saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesProgress, 'Qualified');
      expect(saved.salesRecord['status'], 'completed');
      expect(saved.salesRecord['outcome'], 'Connected');
      expect(saved.salesRecord['customerResponse'], 'Interested');
      expect(saved.salesRecord['assignedTo'], 'staff');
      expect(saved.salesRecord['assignedToName'], 'Staff');
      expect(saved.salesRecord['notes'], 'Sales notes');
      expect(saved.followUpNotes, 'Reminder notes');
      expect(saved.notes, 'Customer notes');
      expect(saved.salesContacts, client.salesContacts);
      await expectLater(save(saved, progress: 'Renewed'), throwsArgumentError);
      await expectLater(
        save(saved, progress: 'No response', due: DateTime(2020)),
        throwsArgumentError,
      );
      await expectLater(save(client), throwsA(isA<PlanSaveConflict>()));
      final nextDue = DateTime.now().add(const Duration(days: 7));
      await save(saved, progress: 'No response', due: nextDue);
      saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesProgress, 'No response');
      expect(saved.salesRecord['status'], 'assigned');
      expect(saved.followUpAt, nextDue);
      expect(
        salesProgressLabel(saved.stage, saved.salesProgress),
        'No response',
      );
      expect(
        (await db.collection('plans').doc(plan.id).get()).data(),
        originalPlan,
      );
      final logs = await service.salesActivity(client.id).first;
      expect(logs, hasLength(2));
      expect(logs.first['previousProgress'], 'Qualified');
      expect(logs.first['progress'], 'No response');
      expect(logs.first['recordedByName'], 'Bharathi');
    },
  );

  testWidgets(
    'Saving a customer update keeps the legacy task assignee and leaves every plan task unchanged',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final client = _client();
      final plan = _plan();
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      await db.collection('plans').doc(plan.id).set(plan.toFirestore());
      final originalPlan = (await db.collection('plans').doc(plan.id).get())
          .data();
      await _openRecord(
        tester,
        client,
        FirestoreService(firestore: db),
        plans: [plan],
      );
      await _choose<String>(tester, 'Update', 'Interested');
      await _choose<bool>(tester, 'Reminder', 'No reminder');
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesProgress, 'Interested');
      expect(saved.salesRecord['assignedTo'], 'admin');
      expect(saved.salesRecord['status'], 'assigned');
      expect(saved.followUpAt, isNull);
      expect(
        (await db.collection('plans').doc(plan.id).get()).data(),
        originalPlan,
      );
      expect(
        matchesSalesTaskQueue(
          customerSalesRecords([saved], [plan]).single,
          SalesTaskQueue.unscheduled,
          DateTime.now(),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Lifecycle progress is stage-specific, explicitly logged, and preserved by profile edits',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      var client = _client().copyWith(notes: 'Preserved customer information');
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      Future<void> save(
        Client baseline,
        ClientStage stage,
        String progress, {
        DateTime? due,
      }) => service.saveCustomerSalesRecord(
        client: baseline,
        actor: _actor,
        title: 'Call',
        action: 'Call',
        notes: '',
        outcome: '',
        completeAction: false,
        dueAt: due,
        nextTitle: '',
        nextAction: '',
        stage: stage,
        customerResponse: 'Not discussed',
        nextStep: 'No next step',
        progress: progress,
      );
      for (final stage in chatFunnelStages) {
        final progress = salesStageProgress[stage]!.first;
        final previous = client;
        await save(client, stage, progress);
        client = Client.fromFirestore(
          await db.collection('clients').doc(client.id).get(),
        );
        expect(client.stage, stage);
        expect(client.salesProgress, progress);
        final logs = await service.salesActivity(client.id).first;
        expect(
          logs.any(
            (log) =>
                log['previousStage'] == previous.stage.name &&
                log['stage'] == stage.name &&
                log['progress'] == progress &&
                log['recordedByName'] == 'Bharathi',
          ),
          isTrue,
        );
        expect(client.notes, 'Preserved customer information');
      }
      await expectLater(
        save(client, ClientStage.click, 'Renewed'),
        throwsArgumentError,
      );
      await expectLater(
        save(client, ClientStage.client, 'Payment verified'),
        throwsArgumentError,
      );
      await expectLater(
        save(
          client,
          ClientStage.lost,
          'Not interested',
          due: DateTime.now().add(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
      expect(client.salesRecord['status'], 'completed');
      expect((await db.collection('payments').get()).docs, isEmpty);
      final stale = client;
      await save(client, ClientStage.retain, 'Renewal due');
      client = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      await expectLater(
        save(stale, ClientStage.refer, 'Ready to ask'),
        throwsA(isA<PlanSaveConflict>()),
      );
      await service.updateClient(client.copyWith(name: 'Updated customer'));
      var updated = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(updated.salesProgress, 'Renewal due');
      await service.updateClient(
        updated.copyWith(stage: ClientStage.refer),
        actor: _actor,
      );
      updated = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(updated.salesProgress, isEmpty);
      expect(updated.stage, ClientStage.refer);
      expect(
        (await service.salesActivity(client.id).first).any(
          (log) =>
              log['event'] == 'Stage changed' &&
              log['previousProgress'] == 'Renewal due',
        ),
        isTrue,
      );
      await save(
        updated,
        ClientStage.refer,
        'Ready to ask',
        due: DateTime.now().add(const Duration(days: 1)),
      );
      updated = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      await service.updateClient(
        updated.copyWith(stage: ClientStage.lost),
        actor: _actor,
      );
      updated = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(updated.followUpAt, isNull);
      expect(updated.salesRecord['status'], 'completed');
      await service.updateClient(
        updated.copyWith(stage: ClientStage.click),
        actor: _actor,
      );
      updated = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(updated.salesRecord['status'], 'assigned');
      expect(updated.salesProgress, isEmpty);
    },
  );

  testWidgets(
    'Stage choices reset incompatible progress without saving implicitly',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final client = _client().copyWith(salesProgress: 'Qualified');
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final service = FirestoreService(firestore: db);
      await _openRecord(tester, client, service);
      expect(find.textContaining('Current progress:'), findsNothing);
      expect(find.textContaining('Current task:'), findsNothing);
      expect(find.textContaining('Current reminder:'), findsNothing);
      expect(find.textContaining('Latest interaction:'), findsNothing);
      expect(find.textContaining('Summary:'), findsNothing);
      expect(find.text('Update customer progress'), findsNothing);
      expect(find.text('Record this interaction'), findsNothing);
      expect(
        find.text(
          'Logs your name, time, selected outcome and customer response.',
        ),
        findsNothing,
      );
      expect(
        find.text('Choose a date and time using the calendar and clock.'),
        findsNothing,
      );
      expect(find.text('Customer activity log'), findsNothing);
      await _choose<ClientStage>(tester, 'Main stage', 'Retain');
      final progress = tester.widget<DropdownButtonFormField<String>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == 'Update',
        ),
      );
      expect(progress.initialValue, isNull);
      await _choose<String>(tester, 'Update', 'Renewal pending');
      final unchanged = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(unchanged.stage, ClientStage.click);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.stage, ClientStage.retain);
      expect(saved.salesProgress, 'Renewal pending');
      expect(saved.salesRecord['action'], 'Update');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Referral creates a separate lead with provenance and named logs without changing the referring customer',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final source = _client().copyWith(
        stage: ClientStage.retain,
        salesProgress: 'Satisfied',
      );
      await db.collection('clients').doc(source.id).set(source.toFirestore());
      final service = FirestoreService(firestore: db);
      await _openRecord(tester, source, service);
      await tester.ensureVisible(find.text('Create referred lead'));
      await tester.tap(find.text('Create referred lead'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New lead name'),
        'New referred customer',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New lead phone'),
        '9876543210',
      );
      await tester.tap(find.text('Create lead'));
      await tester.pumpAndSettle();
      final clients = (await db.collection('clients').get()).docs
          .map(Client.fromFirestore)
          .toList();
      expect(clients, hasLength(2));
      final lead = clients.singleWhere((client) => client.id != source.id);
      expect(lead.stage, ClientStage.click);
      expect(lead.salesProgress, 'Not contacted');
      expect(lead.referredByClientId, source.id);
      expect(lead.salesRecord['title'], 'Call referred lead');
      expect(
        clients.singleWhere((client) => client.id == source.id).salesProgress,
        'Satisfied',
      );
      expect(
        (await service.salesActivity(source.id).first).single['referredLeadId'],
        lead.id,
      );
      expect(
        (await service.salesActivity(lead.id).first).single['recordedByName'],
        'Bharathi',
      );
      expect((await db.collection('plans').get()).docs, isEmpty);
      await service.updateClient(
        lead.copyWith(name: 'Renamed lead', referredByClientId: 'wrong-source'),
      );
      final renamed = Client.fromFirestore(
        await db.collection('clients').doc(lead.id).get(),
      );
      expect(renamed.referredByClientId, source.id);
      await expectLater(
        service.createReferredLead(
          source: source,
          actor: AppUser(
            uid: 'reader',
            name: 'Reader',
            email: '',
            isAdmin: false,
            isStaff: true,
          ),
          name: 'Not permitted',
          phone: '9876543211',
        ),
        throwsStateError,
      );
      expect((await db.collection('clients').get()).docs, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Removed popup sections stay hidden while notes, payments and activity remain stored',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final client = _client().copyWith(
        followUpNotes: 'Saved reminder note',
        salesRecord: {
          'notes': 'Saved sales note',
          'legacyNotes': ['Older sales note'],
        },
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final activity = db
          .collection('clients')
          .doc(client.id)
          .collection('salesActivity')
          .doc('existing');
      final originalActivity = {
        'event': 'Record updated',
        'title': 'Pricing',
        'at': DateTime(2026, 10, 1).toIso8601String(),
        'recordedByName': 'Admin',
      };
      await activity.set(originalActivity);
      for (final status in PaymentStatus.values) {
        final payment = PaymentRecord(
          id: status.name,
          clientId: client.id,
          clientName: client.name,
          amount: status == PaymentStatus.verified ? 100 : 500,
          transactionId: status.name,
          paymentMethod: 'Cash',
          paymentDate: DateTime.now(),
          createdDate: DateTime.now(),
          status: status,
        );
        await db
            .collection('payments')
            .doc(payment.id)
            .set(payment.toFirestore());
      }
      await _openRecord(tester, client, FirestoreService(firestore: db));
      expect(
        find.textContaining('1 verified record(s) · Total 100.00'),
        findsNothing,
      );
      expect(find.text('Verified payments'), findsNothing);
      expect(find.text('Previous sales notes (read-only)'), findsNothing);
      expect(find.text('Customer activity log'), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('customer-sales-notes')),
            )
            .controller!
            .text,
        'Saved sales note',
      );
      expect(find.text('Saved reminder note'), findsNothing);
      expect(find.text('Older sales note'), findsNothing);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.stage, ClientStage.click);
      expect(saved.salesRecord['notes'], 'Saved sales note');
      expect(saved.salesRecord['legacyNotes'], contains('Older sales note'));
      expect(saved.followUpNotes, 'Saved reminder note');
      expect((await activity.get()).data(), originalActivity);
      expect((await db.collection('payments').get()).docs, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Web transaction conflicts expose the original error and can reopen and save the latest record',
    (tester) async {
      final db = _BoxingFirestore();
      final client = _client().copyWith(
        salesRecord: {
          'revision': 'old',
          'action': 'Call',
          'title': 'Call',
          'status': 'assigned',
        },
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final service = FirestoreService(firestore: db);
      await _openRecord(tester, client, service);
      await db.collection('clients').doc(client.id).update({
        'salesRecord': {...client.salesRecord, 'revision': 'new'},
      });
      await _choose<String>(tester, 'Update', 'No response');
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(
        find.text('The Sales record changed. Reopen it before saving.'),
        findsOneWidget,
      );
      expect(find.textContaining('converted Future'), findsNothing);
      expect((await service.salesActivity(client.id).first), isEmpty);
      await tester.ensureVisible(find.text('Reopen latest record'));
      await tester.tap(find.text('Reopen latest record'));
      await tester.pumpAndSettle();
      expect(
        find.text('The Sales record changed. Reopen it before saving.'),
        findsNothing,
      );
      await _choose<String>(tester, 'Update', 'No response');
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerSalesRecordDialog), findsNothing);
      expect((await service.salesActivity(client.id).first), hasLength(1));
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesRecord['status'], 'assigned');
      expect(saved.salesProgress, 'No response');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'One customer row uses nearest legacy reminder and preserves other tasks',
    () {
      final records = customerSalesRecords([_client()], [_plan()]);
      expect(records, hasLength(1));
      expect(records.single.feature, 'Sales / Call: First call');
      expect(_plan().features, hasLength(2));
    },
  );

  test(
    'Completion adds named immutable activity and next reminder without another task',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      final client = _client();
      final plan = _plan();
      await db.collection('clients').doc(client.id).set({
        ...client.toFirestore(),
        'salesContacts': client.salesContacts,
      });
      await db.collection('plans').doc(plan.id).set(plan.toFirestore());
      final nextDue = DateTime(2026, 10, 15, 15);
      Future<void> save(
        Client baseline, {
        bool complete = true,
        DateTime? due,
      }) => service.saveCustomerSalesRecord(
        client: baseline,
        actor: _actor,
        title: 'First call',
        action: 'Call',
        notes: 'Customer wants pricing',
        outcome: 'Proposal requested',
        completeAction: complete,
        dueAt: due,
        nextTitle: 'Send pricing',
        nextAction: 'WhatsApp',
        stage: client.stage,
        legacyTask: baseline.salesRecord.isEmpty
            ? (plan: plan, feature: plan.features.first)
            : null,
      );
      await save(client, due: nextDue);
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesRecord['title'], 'Send pricing');
      expect(saved.salesRecord['status'], 'assigned');
      expect(saved.followUpAt, nextDue);
      expect(saved.salesContacts, client.salesContacts);
      await service.updateClient(
        client.copyWith(name: 'Updated customer name'),
      );
      final afterProfileEdit = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(afterProfileEdit.salesRecord, saved.salesRecord);
      expect(afterProfileEdit.followUpAt, nextDue);
      final savedPlan = Plan.fromFirestore(
        await db.collection('plans').doc(plan.id).get(),
      );
      expect(savedPlan.features, plan.features);
      expect(taskStatus(savedPlan, plan.features.first), TaskStatus.completed);
      expect(
        savedPlan.taskWorkflow[plan.features.last],
        plan.taskWorkflow[plan.features.last],
      );
      final log = (await service.salesActivity(client.id).first).single;
      expect(log['recordedByName'], 'Bharathi');
      expect(log['recordedBy'], 'admin');
      expect(log['outcome'], 'Proposal requested');
      expect(log['notes'], 'Customer wants pricing');
      expect(log['nextReminder'], nextDue.toIso8601String());
      expect(log['previousReminder'], DateTime(2026, 10, 1).toIso8601String());
      expect(DateTime.tryParse(log['at'] as String), isNotNull);
      expect(
        customerSalesRecords([saved], [savedPlan]).single.feature,
        'Sales / WhatsApp: Send pricing',
      );
      await expectLater(save(client), throwsA(isA<PlanSaveConflict>()));
      expect(await service.salesActivity(client.id).first, hasLength(1));
      await save(saved);
      final completed = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(completed.salesRecord['status'], 'completed');
      expect(completed.followUpAt, isNull);
      expect(
        taskDueAt(
          customerSalesRecords([completed], [savedPlan]).single.plan,
          customerSalesRecords([completed], [savedPlan]).single.feature,
        ),
        isNull,
      );
      expect(await service.salesActivity(client.id).first, hasLength(2));
    },
  );

  testWidgets(
    'Popup saves a simple update and exact reminder without creating another task',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final db = FakeFirebaseFirestore();
      final client = _client();
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final service = FirestoreService(firestore: db);
      await _openRecord(tester, client, service);
      expect(find.byType(TextField), findsOneWidget);
      await _choose<String>(tester, 'Update', 'No response');
      for (final label in [
        'Action',
        'Outcome',
        'Customer response',
        'Next step',
      ]) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DropdownButtonFormField<String> &&
                widget.decoration.labelText == label,
          ),
          findsNothing,
        );
      }
      expect(find.text('Complete current action'), findsNothing);
      final now = DateTime.now();
      final nextDue = DateTime(now.year, now.month, now.day + 7, 10, 31);
      await _pickReminder(tester, nextDue);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesRecord['title'], 'No response');
      expect(saved.salesProgress, 'No response');
      expect(saved.followUpAt, nextDue);
      expect(saved.salesRecord['reminderDays'], isNull);
      expect(saved.salesRecord['reminderTimeMinutes'], isNull);
      final log = (await service.salesActivity(client.id).first).single;
      expect(log['event'], 'Progress updated');
      expect(log['progress'], 'No response');
      expect(log['recordedByName'], 'Bharathi');
      expect(log['outcome'], isNull);
      expect(log['customerResponse'], isNull);
      expect(log['nextStep'], isNull);
      expect(log['notes'], isNull);
      expect(log['nextReminder'], nextDue.toIso8601String());
      expect((await db.collection('plans').get()).docs, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Do not contact independently blocks shortcuts and reminders until saved permission is restored',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final client = _client().copyWith(contactPhone: '+919876543210');
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      await _openRecord(tester, client, FirestoreService(firestore: db));
      await tester.ensureVisible(find.text('Do not contact'));
      await tester.tap(find.text('Do not contact'));
      await tester.pumpAndSettle();
      for (final text in ['Call customer', 'WhatsApp']) {
        final shortcut = find.widgetWithText(TextButton, text);
        expect(tester.widget<TextButton>(shortcut).onPressed, isNull);
      }
      final reminder = tester.widget<DropdownButtonFormField<bool>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<bool> &&
              widget.decoration.labelText == 'Reminder',
        ),
      );
      expect(reminder.onChanged, isNull);
      expect(find.text('No reminder'), findsOneWidget);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.doNotContact, isTrue);
      expect(saved.followUpAt, isNull);
      await _openRecord(tester, saved, FirestoreService(firestore: db));
      await tester.ensureVisible(find.text('Do not contact'));
      await tester.tap(find.text('Do not contact'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Call customer'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final allowed = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(allowed.doNotContact, isFalse);
      await _openRecord(tester, allowed, FirestoreService(firestore: db));
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Call customer'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Calendar reminders preserve exact times, reject past dates, support cancellation and clearing',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final original = DateTime(2020, 1, 1, 10, 17);
      final client = _client().copyWith(followUpAt: original);
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      final service = FirestoreService(firestore: db);
      await _openRecord(tester, client, service);
      expect(find.textContaining('10:17 AM'), findsOneWidget);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.followUpAt, original);
      await _openRecord(tester, saved, service);
      final now = DateTime.now();
      await _pickReminder(
        tester,
        DateTime(now.year, now.month, now.day - 1, 10, 17),
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The selected time has passed'),
        findsOneWidget,
      );
      expect((await service.salesActivity(client.id).first), hasLength(1));
      final nextDue = DateTime(now.year, now.month, now.day + 1, 10, 31);
      await _pickReminder(tester, nextDue);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final updated = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(updated.followUpAt, nextDue);
      await _openRecord(tester, updated, service);
      final reminder = find.byKey(const ValueKey('customer-sales-reminder'));
      await tester.ensureVisible(reminder);
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      await _pickReminder(
        tester,
        DateTime(now.year, now.month, now.day + 2, 15),
        cancelTime: true,
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final afterCancel = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(afterCancel.followUpAt, nextDue);
      await _openRecord(tester, afterCancel, service);
      await tester.ensureVisible(find.byTooltip('Clear reminder'));
      await tester.tap(find.byTooltip('Clear reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final cleared = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(cleared.followUpAt, isNull);
      await _openRecord(tester, cleared, service);
      await _choose<bool>(tester, 'Reminder', 'Set date & time');
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No reminder'), findsOneWidget);
      await _pickReminder(tester, nextDue, cancelTime: true);
      expect(find.text('No reminder'), findsOneWidget);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(
        Client.fromFirestore(
          await db.collection('clients').doc(client.id).get(),
        ).followUpAt,
        isNull,
      );
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Dropdown intervals use local calendar days and reject invalid values',
    () {
      final anchor = DateTime(2026, 12, 29, 23, 59);
      for (final days in salesReminderDays.keys) {
        expect(
          salesReminderAt(anchor, days, 630),
          DateTime(2026, 12, 29 + days, 10, 30),
        );
      }
      expect(() => salesReminderAt(anchor, -1, 630), throwsArgumentError);
      expect(() => salesReminderAt(anchor, 7, 1440), throwsArgumentError);
      expect(normalizedSalesAction('Payment Follow-up'), 'Payment follow-up');
      expect(normalizedSalesAction('Unknown'), isNull);
      expect(
        suggestedSalesNextStep('Call', 'Busy', 'Not discussed'),
        'Call again',
      );
    },
  );

  test(
    'Structured record preserves notes, reports payments, and enforces contact permission',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      final client = _client().copyWith(
        notes: 'Original customer details',
        followUpNotes: 'Legacy reminder notes',
        salesRecord: {
          'notes': 'Old sales notes',
          'title': 'Old title',
          'action': 'Call',
        },
      );
      await db.collection('clients').doc(client.id).set(client.toFirestore());
      Future<void> save(
        Client baseline, {
        String action = 'Call',
        String outcome = 'Connected',
        String response = 'Not discussed',
        bool blocked = false,
        String step = 'No next step',
        DateTime? dueAt,
        int? days,
        int? minutes,
        bool complete = true,
      }) => service.saveCustomerSalesRecord(
        client: baseline,
        actor: _actor,
        title: action,
        action: action,
        notes: '',
        outcome: outcome,
        completeAction: complete,
        dueAt: dueAt,
        nextTitle: step,
        nextAction: salesNextSteps[step] ?? '',
        stage: baseline.stage,
        customerResponse: response,
        nextStep: step,
        doNotContact: blocked,
        reminderDays: days,
        reminderTimeMinutes: minutes,
      );
      await save(
        client,
        action: 'Payment follow-up',
        outcome: 'Full payment reported',
      );
      var saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesRecord['title'], 'Payment follow-up');
      expect(saved.salesRecord['notes'], 'Old sales notes');
      expect(
        saved.salesRecord['legacyNotes'],
        contains('Legacy reminder notes'),
      );
      expect(saved.followUpNotes, 'Legacy reminder notes');
      expect(saved.notes, 'Original customer details');
      expect((await db.collection('payments').get()).docs, isEmpty);
      expect(saved.stage, client.stage);
      await save(saved, complete: false);
      saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.salesRecord['status'], 'completed');
      await expectLater(
        save(saved, step: 'Call again', dueAt: DateTime(2020, 1, 1)),
        throwsArgumentError,
      );
      await expectLater(
        save(saved, action: 'Call', outcome: 'Sent'),
        throwsArgumentError,
      );
      await save(saved, response: 'Do not contact', blocked: true);
      saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.doNotContact, isTrue);
      final now = DateTime.now();
      await expectLater(
        save(
          saved,
          blocked: true,
          step: 'Call again',
          dueAt: salesReminderAt(now, 7, 600),
          days: 7,
          minutes: 600,
        ),
        throwsArgumentError,
      );
      await save(
        saved,
        blocked: false,
        step: 'Call again',
        dueAt: salesReminderAt(now, 7, 600),
        days: 7,
        minutes: 600,
      );
      saved = Client.fromFirestore(
        await db.collection('clients').doc(client.id).get(),
      );
      expect(saved.doNotContact, isFalse);
      final log = (await service.salesActivity(client.id).first).first;
      expect(log['previousDoNotContact'], isTrue);
      expect(log['doNotContact'], isFalse);
      expect(log['reminderDays'], 7);
      expect(log['recordedByName'], 'Bharathi');
    },
  );
}
