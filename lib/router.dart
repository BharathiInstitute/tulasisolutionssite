import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/constants/enums.dart';
import 'core/chat/chat.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/auth_guard_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/admin/dashboard/admin_dashboard_screen.dart';
import 'features/admin/dashboard/my_dashboard_screen.dart';
import 'features/admin/client_list/client_list_screen.dart';
import 'features/admin/client_list/stage_group_client_list_screen.dart';
import 'features/admin/client_profile/client_profile_screen.dart';
import 'features/admin/setup_checklist/add_checklist_item_screen.dart';
import 'features/admin/goals/goals_management_screen.dart';
import 'features/admin/users/user_management_screen.dart';
import 'features/admin/payments/payments_screen.dart';
import 'features/admin/tasks/tasks_screen.dart';
import 'features/admin/performance/performance_screens.dart';
import 'features/admin/tasks/my_assigned_tasks_screen.dart';
import 'features/reports/weekly_reports_screen.dart';
import 'features/chat/conversations_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/template_management_screen.dart';

class AuthStateNotifier extends ChangeNotifier {
  bool _hasResolvedInitialState = false;

  bool get hasResolvedInitialState => _hasResolvedInitialState;

  AuthStateNotifier(FirebaseAuth auth) {
    auth.authStateChanges().listen((_) {
      _hasResolvedInitialState = true;
      notifyListeners();
    });
  }
}

final authStateNotifier = AuthStateNotifier(FirebaseAuth.instance);

final router = GoRouter(
  refreshListenable: authStateNotifier,
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final location = state.matchedLocation;
    const publicLocations = {'/login', '/admin/login', '/forgot-password'};

    if (!authStateNotifier.hasResolvedInitialState) {
      return null;
    }

    if (user == null) {
      if (location == '/') return '/admin/login';
      return publicLocations.contains(location) ? null : '/admin/login';
    }

    if (location == '/' || location == '/login' || location == '/admin/login') {
      return '/auth-guard';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/admin/login'),
    GoRoute(path: '/login', redirect: (context, state) => '/admin/login'),
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordScreen(
        initialEmail: state.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(
      path: '/account-details',
      redirect: (context, state) => '/auth-guard',
    ),
    GoRoute(
      path: '/auth-guard',
      builder: (context, state) => const AuthGuardScreen(),
    ),
    GoRoute(
      path: '/staff-access',
      builder: (context, state) => const StaffAccessRequiredScreen(),
    ),
    // Admin Routes
    GoRoute(path: '/admin', redirect: (context, state) => '/admin/dashboard'),
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/my-dashboard',
      builder: (context, state) => const MyDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/performance',
      builder: (context, state) => const AdminPerformanceScreen(),
    ),
    GoRoute(
      path: '/admin/my-performance',
      builder: (context, state) => const StaffPerformanceScreen(),
    ),
    GoRoute(
      path: '/admin/leads',
      builder: (context, state) => const ClientListScreen(),
    ),
    GoRoute(
      path: '/admin/leads/:clientId',
      builder: (context, state) {
        final clientId = state.pathParameters['clientId']!;
        return ClientProfileScreen(clientId: clientId);
      },
    ),
    GoRoute(
      path: '/admin/leads/:clientId/checklist/add',
      builder: (context, state) {
        final clientId = state.pathParameters['clientId']!;
        return AddChecklistItemScreen(clientId: clientId);
      },
    ),
    GoRoute(
      path: '/admin/leads/:clientId/goals/add',
      builder: (context, state) {
        final clientId = state.pathParameters['clientId']!;
        return GoalsManagementScreen(clientId: clientId);
      },
    ),
    GoRoute(
      path: '/admin/clients',
      redirect: (context, state) => '/admin/leads',
    ),
    GoRoute(
      path: '/admin/clients/:clientId',
      redirect: (context, state) =>
          '/admin/leads/${state.pathParameters['clientId']}',
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UserManagementScreen(),
    ),
    GoRoute(
      path: '/admin/consultations',
      builder: (context, state) => const StageGroupClientListScreen(
        title: 'Clients',
        icon: Icons.people,
        currentRoute: '/admin/consultations',
        planTypes: {PlanType.setup, PlanType.subscription},
        stages: {
          ClientStage.register,
          ClientStage.consult,
          ClientStage.followUp,
          ClientStage.client,
          ClientStage.retain,
        },
      ),
    ),
    GoRoute(
      path: '/admin/payments',
      builder: (context, state) => const PaymentsScreen(),
    ),
    GoRoute(
      path: '/admin/tasks',
      builder: (context, state) => const TasksScreen(),
    ),
    GoRoute(
      path: '/admin/completed-tasks',
      builder: (context, state) => const CompletedTasksScreen(),
    ),
    GoRoute(
      path: '/admin/my-tasks',
      builder: (context, state) => const MyAssignedTasksScreen(),
    ),
    GoRoute(
      path: '/admin/my-completed-tasks',
      builder: (context, state) => const MyCompletedTasksScreen(),
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => const WeeklyReportsScreen(),
    ),
    GoRoute(
      path: '/admin/setup',
      redirect: (context, state) => '/admin/consultations',
    ),
    GoRoute(
      path: '/admin/subscription',
      redirect: (context, state) => '/admin/consultations',
    ),
    // Chat Routes
    GoRoute(
      path: '/admin/chat',
      builder: (context, state) => const ConversationsScreen(),
    ),
    GoRoute(
      path: '/admin/templates',
      builder: (context, state) => const TemplateManagementScreen(),
    ),
    GoRoute(
      path: '/admin/chat/:id',
      builder: (context, state) {
        final conversation = state.extra as Conversation;
        return ChatScreen(conversation: conversation);
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ConversationsScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      redirect: (context, state) =>
          state.extra is Conversation ? null : '/chat',
      builder: (context, state) =>
          ChatScreen(conversation: state.extra! as Conversation),
    ),
  ],
);
