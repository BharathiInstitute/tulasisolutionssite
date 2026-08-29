import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'core/constants/enums.dart';
import 'core/chat/chat.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/auth_guard_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/account_details_screen.dart';
import 'features/admin/client_list/client_list_screen.dart';
import 'features/admin/client_list/stage_group_client_list_screen.dart';
import 'features/admin/client_profile/client_profile_screen.dart';
import 'features/admin/setup_checklist/add_checklist_item_screen.dart';
import 'features/admin/goals/goals_management_screen.dart';
import 'features/admin/users/user_management_screen.dart';
import 'features/admin/plans/plans_screen.dart';
import 'features/admin/payments/payments_screen.dart';
import 'features/admin/tasks/tasks_screen.dart';
import 'features/client/dashboard/client_dashboard_screen.dart';
import 'features/client/goals/client_goals_view_screen.dart';
import 'features/client/tasks/client_tasks_screen.dart';
import 'features/chat/conversations_screen.dart';
import 'features/chat/chat_screen.dart';

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(FirebaseAuth auth) {
    auth.authStateChanges().listen((_) => notifyListeners());
  }
}

final authStateNotifier = AuthStateNotifier(FirebaseAuth.instance);

final router = GoRouter(
  refreshListenable: authStateNotifier,
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final location = state.matchedLocation;
    const publicLocations = {
      '/login',
      '/user/login',
      '/admin/login',
      '/forgot-password',
    };

    if (user == null) {
      if (location == '/') return '/user/login';
      return publicLocations.contains(location) ? null : '/user/login';
    }

    if (location == '/' ||
        location == '/login' ||
        location == '/user/login' ||
        location == '/admin/login') {
      return '/auth-guard';
    }

    if (location.startsWith('/admin')) {
      final isAdmin = await FirebaseAuthService().isUserAdmin(user.uid);
      if (!isAdmin) {
        return '/client/dashboard';
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/login'),
    GoRoute(path: '/login', redirect: (context, state) => '/user/login'),
    GoRoute(
      path: '/user/login',
      builder: (context, state) => const AuthScreen(isAdmin: false),
    ),
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AuthScreen(isAdmin: true),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/account-details',
      builder: (context, state) => const AccountDetailsScreen(),
    ),
    GoRoute(
      path: '/auth-guard',
      builder: (context, state) => const AuthGuardScreen(),
    ),
    // Admin Routes
    GoRoute(path: '/admin', redirect: (context, state) => '/admin/leads'),
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
          ClientStage.refer,
        },
      ),
    ),
    GoRoute(
      path: '/admin/plans',
      builder: (context, state) => const PlansScreen(),
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
    // Client Routes
    GoRoute(path: '/client', redirect: (context, state) => '/client/dashboard'),
    GoRoute(
      path: '/client/dashboard',
      builder: (context, state) => const ClientDashboardScreen(),
    ),
    GoRoute(
      path: '/client/goals',
      builder: (context, state) {
        return const ClientGoalsViewScreen();
      },
    ),
    GoRoute(
      path: '/client/tasks',
      builder: (context, state) => const ClientTasksScreen(),
    ),
  ],
);
