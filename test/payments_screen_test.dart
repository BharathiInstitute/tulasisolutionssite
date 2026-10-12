import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/features/admin/payments/payments_screen.dart';

Client _client(String id, String name) => Client(
  id: id,
  name: name,
  category: '',
  contactEmail: '',
  contactPhone: '',
  stage: ClientStage.client,
  createdDate: DateTime(2026, 10, 1),
);

class _PaymentAuthService implements FirebaseAuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PaymentService implements FirestoreService {
  final List<Client> clients;
  final List<PaymentRecord> payments;
  final saved = <PaymentRecord>[];
  bool failSave = false;
  int clientLoads = 0;
  Future<List<Client>> Function()? loadClients;

  _PaymentService(this.clients, {this.payments = const []});

  @override
  Stream<List<PaymentRecord>> getPaymentsStream() => Stream.value(payments);

  @override
  Future<List<Client>> getClientsOnce() async {
    clientLoads++;
    return loadClients == null ? clients : await loadClients!();
  }

  @override
  Future<Client?> getClient(String clientId, {bool serverOnly = false}) async =>
      clients.where((client) => client.id == clientId).firstOrNull;

  @override
  Future<void> createPayment(PaymentRecord payment) async {
    if (failSave) throw StateError('Connection unavailable');
    saved.add(payment);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _showPayments(
  WidgetTester tester,
  _PaymentService service, {
  double width = 766,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 760);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: '/admin/payments',
    routes: [
      GoRoute(
        path: '/admin/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseAuthServiceProvider.overrideWithValue(_PaymentAuthService()),
        firestoreServiceProvider.overrideWithValue(service),
        visiblePlansProvider.overrideWith((ref) {
          throw StateError('Recording payments must not load plans');
        }),
        currentUserProfileProvider.overrideWith(
          (ref) async => AppUser(
            uid: 'admin',
            email: 'admin@example.com',
            name: 'Admin',
            isAdmin: true,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectClient(WidgetTester tester, String name) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'payment popup opens immediately while clients load and ignores rapid clicks',
    (tester) async {
      final pending = Completer<List<Client>>();
      final service = _PaymentService([_client('client', 'Client')])
        ..loadClients = () => pending.future;
      await _showPayments(tester, service);
      expect(service.clientLoads, 0);
      final button = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Loading clients...'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save pending'),
            )
            .onPressed,
        isNull,
      );
      expect(service.clientLoads, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Loading clients...'), findsOneWidget);
      pending.complete(service.clients);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(find.text('Loading clients...'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cancel during client loading does not open a delayed popup', (
    tester,
  ) async {
    final pending = Completer<List<Client>>();
    final service = _PaymentService([_client('client', 'Client')])
      ..loadClients = () => pending.future;
    await _showPayments(tester, service);
    await tester.tap(find.text('Record payment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    pending.complete(service.clients);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(service.saved, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'client loading failures are visible and retry recovers inside the popup',
    (tester) async {
      final service = _PaymentService([_client('client', 'Client')])
        ..loadClients = () async =>
            throw StateError('Client access unavailable');
      await _showPayments(tester, service);
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Could not load clients:'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save pending'),
            )
            .onPressed,
        isNull,
      );
      final retried = Completer<List<Client>>();
      service.loadClients = () => retried.future;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Loading clients...'), findsOneWidget);
      expect(service.clientLoads, 2);
      retried.complete(service.clients);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load clients:'), findsNothing);
      await _selectClient(tester, 'Client');
      await tester.enterText(_field('Amount (INR)'), '100');
      await tester.enterText(_field('Transaction / reference ID'), 'REF');
      await tester.tap(find.text('Save pending'));
      await tester.pumpAndSettle();
      expect(service.saved, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'empty clients explain why saving is disabled and can be refreshed',
    (tester) async {
      final service = _PaymentService([]);
      await _showPayments(tester, service);
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No clients available. Add a client before recording a payment.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save pending'),
            )
            .onPressed,
        isNull,
      );
      service.clients.add(_client('client', 'Client'));
      await tester.tap(find.text('Refresh clients'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(service.clientLoads, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [320.0, 766.0, 1280.0]) {
    testWidgets(
      'records payment without a plan and fits long client names at $width',
      (tester) async {
        final longName = List.filled(15, 'Long client business name').join(' ');
        final service = _PaymentService([
          _client('first', longName),
          _client('second', 'Second client'),
        ]);
        await _showPayments(tester, service, width: width);
        await tester.tap(find.text('Record payment'));
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
        expect(find.text('Plan'), findsNothing);
        expect(find.text('Select a client first'), findsNothing);
        expect(tester.takeException(), isNull);
        await _selectClient(tester, longName);
        expect(tester.takeException(), isNull);
        await tester.enterText(_field('Amount (INR)'), '1250.50');
        await _selectClient(tester, 'Second client');
        expect(
          tester.widget<TextField>(_field('Amount (INR)')).controller!.text,
          '1250.50',
        );
        await tester.ensureVisible(_field('Transaction / reference ID'));
        await tester.enterText(
          _field('Transaction / reference ID'),
          ' REF-123 ',
        );
        await tester.ensureVisible(_field('Notes (optional)'));
        await tester.enterText(
          _field('Notes (optional)'),
          ' Payment received ',
        );
        await tester.tap(find.text('Save pending'));
        await tester.pumpAndSettle();
        final saved = service.saved.single;
        expect(saved.clientId, 'second');
        expect(saved.clientName, 'Second client');
        expect(saved.amount, 1250.50);
        expect(saved.planId, isNull);
        expect(saved.planName, isNull);
        expect(saved.transactionId, 'REF-123');
        expect(saved.notes, 'Payment received');
        expect(saved.paymentMethod, 'UPI');
        expect(saved.status, PaymentStatus.pending);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'payment validation requires a client, finite positive amount and reference',
    (tester) async {
      final service = _PaymentService([_client('client', 'Client')]);
      await _showPayments(tester, service);
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save pending'));
      await tester.pumpAndSettle();
      expect(find.text('Select a client'), findsOneWidget);
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(find.text('Enter the transaction ID'), findsOneWidget);
      await _selectClient(tester, 'Client');
      await tester.enterText(_field('Transaction / reference ID'), 'REF');
      for (final amount in ['0', '-1', 'NaN', 'Infinity', 'text']) {
        await tester.enterText(_field('Amount (INR)'), amount);
        await tester.tap(find.text('Save pending'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid amount'), findsOneWidget);
        expect(service.saved, isEmpty);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.saved, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed payment saves remain visible and can be retried', (
    tester,
  ) async {
    final service = _PaymentService([_client('client', 'Client')])
      ..failSave = true;
    await _showPayments(tester, service);
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    await _selectClient(tester, 'Client');
    await tester.enterText(_field('Amount (INR)'), '100');
    await tester.enterText(_field('Transaction / reference ID'), 'REF');
    await tester.tap(find.text('Save pending'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Could not record payment:'), findsOneWidget);
    expect(service.saved, isEmpty);
    service.failSave = false;
    await tester.tap(find.text('Save pending'));
    await tester.pumpAndSettle();
    expect(service.saved, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final planName in [null, 'Historical plan']) {
    testWidgets('UPI details support payments with plan=$planName', (
      tester,
    ) async {
      final client = _client('client', 'Client');
      final payment = PaymentRecord(
        id: 'payment',
        clientId: client.id,
        clientName: client.name,
        planId: planName == null ? null : 'plan',
        planName: planName,
        amount: 321.50,
        transactionId: 'REF-123',
        paymentMethod: 'UPI',
        paymentDate: DateTime(2026, 10, 10),
        createdDate: DateTime(2026, 10, 10),
      );
      final service = _PaymentService([client], payments: [payment]);
      await _showPayments(tester, service);
      await tester.tap(find.widgetWithText(ActionChip, 'Copy UPI message'));
      await tester.pumpAndSettle();
      final message = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(message.contains('Selected plan'), isFalse);
      expect(message.contains('Plan:'), planName != null);
      final linkLine = message
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('Pay securely using this UPI link: '),
          );
      final link = Uri.parse(
        linkLine.substring('Pay securely using this UPI link: '.length),
      );
      expect(link.queryParameters['am'], '321.50');
      expect(link.queryParameters['tr'], 'REF-123');
      expect(
        link.queryParameters['tn'],
        planName == null
            ? 'Payment to Tulasi Solutions'
            : 'Payment for $planName',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
