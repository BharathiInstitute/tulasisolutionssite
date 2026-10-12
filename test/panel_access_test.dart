import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/access/panel_access.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';

class _DrawerAuthService implements FirebaseAuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('removed Clients panel is not a route or staff permission option', () {
    expect(adminPanelLabels.containsKey('clients'), isFalse);
    expect(adminPanelRoutes.containsKey('clients'), isFalse);
    expect(panelForAdminRoute('/admin/consultations'), isNull);
    expect(panelForAdminRoute('/admin/leads'), 'leads');
    expect(panelForAdminRoute('/admin/sales-tasks'), 'leads');
  });

  test(
    'historical client-record access is retained without granting Sales Pipeline access',
    () {
      final staff = AppUser.fromMap('staff', {
        'email': 'staff@example.com',
        'name': 'Staff',
        'isAdmin': false,
        'isStaff': true,
        'panels': ['clients', 'unknown-panel'],
      });
      expect(staff.panels, ['clients']);
      expect(staff.canAccessPanel('clients'), isTrue);
      expect(canAccessAdminPanel(staff, 'leads'), isFalse);
      expect(firstGrantedAdminRoute(staff), '/admin/my-dashboard');
    },
  );

  test('removed reports route has no panel access mapping', () {
    expect(panelForAdminRoute('/admin/reports'), isNull);
    expect(adminPanelRoutes.values, isNot(contains('/admin/reports')));
    expect(panelForAdminRoute('/admin/tasks'), 'tasks');
    expect(panelForAdminRoute('/admin/completed-tasks'), 'tasks');
  });

  for (final admin in [true, false]) {
    for (final desktop in [true, false]) {
      testWidgets(
        'removed panels are absent from navigation: admin=$admin desktop=$desktop',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(desktop ? 1200 : 700, 1000);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final router = GoRouter(
            initialLocation: '/admin/tasks',
            routes: [
              GoRoute(
                path: '/admin/tasks',
                builder: (context, state) => const AppShell(
                  isAdmin: true,
                  currentRoute: '/admin/tasks',
                  title: 'Tasks',
                  body: SizedBox.shrink(),
                ),
              ),
              for (final route in ['/admin/leads', '/admin/sales-tasks'])
                GoRoute(
                  path: route,
                  builder: (context, state) => AppShell(
                    isAdmin: true,
                    currentRoute: route,
                    title: 'Sales navigation test',
                    body: const SizedBox.shrink(),
                  ),
                ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                firebaseAuthServiceProvider.overrideWithValue(
                  _DrawerAuthService(),
                ),
                currentUserProfileProvider.overrideWith(
                  (ref) async => AppUser(
                    uid: 'staff',
                    email: 'staff@example.com',
                    name: 'Staff',
                    isAdmin: admin,
                    isStaff: true,
                    panels: const ['tasks', 'clients', 'leads', 'payments'],
                  ),
                ),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();
          if (!desktop) {
            tester
                .state<ScaffoldState>(find.byType(Scaffold).first)
                .openDrawer();
            await tester.pumpAndSettle();
          }
          expect(find.text('Weekly Reports'), findsNothing);
          expect(find.text('Clients'), findsNothing);
          expect(find.text('Sales Tasks'), findsOneWidget);
          expect(find.text('Sales Pipeline'), findsOneWidget);
          expect(find.text('Payments'), findsOneWidget);
          expect(find.text('Assign Tasks'), findsOneWidget);
          expect(find.text('Completed Tasks'), findsOneWidget);
          expect(find.text('My Tasks'), findsOneWidget);
          await tester.tap(find.text('Sales Tasks'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/admin/sales-tasks');
          if (!desktop) {
            tester
                .state<ScaffoldState>(find.byType(Scaffold).first)
                .openDrawer();
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Sales Pipeline'));
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/admin/leads');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  test('staff without explicit panels can access all personal sections', () {
    final staff = AppUser(
      uid: 'staff@example.com',
      email: 'staff@example.com',
      name: 'Staff Member',
      isAdmin: false,
      isStaff: true,
    );

    expect(hasGrantedAdminPanel(staff), isTrue);
    for (final route in [
      '/admin/my-dashboard',
      '/admin/my-performance',
      '/admin/my-tasks',
      '/admin/my-completed-tasks',
    ]) {
      expect(canAccessAdminPanel(staff, panelForAdminRoute(route)!), isTrue);
    }
    expect(firstGrantedAdminRoute(staff), '/admin/my-dashboard');
    for (final panel in ['users', 'tasks', 'performance', 'payments', 'chat']) {
      expect(canAccessAdminPanel(staff, panel), isFalse);
    }
  });

  test('ordinary authenticated accounts do not gain personal staff access', () {
    final user = AppUser(
      uid: 'ordinary-user',
      email: 'user@example.com',
      name: 'User',
      isAdmin: false,
    );
    for (final panel in defaultStaffPanels) {
      expect(canAccessAdminPanel(user, panel), isFalse);
      expect(canAccessAdminPanel(null, panel), isFalse);
    }
  });
}
