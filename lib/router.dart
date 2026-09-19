import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tulasisolutionssite/core/services/firebase_service.dart';
import 'package:tulasisolutionssite/core/access/panel_access.dart';
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
import 'features/admin/plans/plans_screen.dart';
import 'features/admin/payments/payments_screen.dart';
import 'features/admin/tasks/tasks_screen.dart';
import 'features/admin/brand_briefs/brand_briefs_screen.dart';
import 'features/admin/website_briefs/website_briefs_screen.dart';
import 'features/admin/performance/performance_screens.dart';
import 'features/client/dashboard/client_dashboard_screen.dart';
import 'features/client/goals/client_goals_view_screen.dart';
import 'features/client/tasks/client_tasks_screen.dart';
import 'features/client/brand_brief/client_brand_brief_screen.dart';
import 'features/client/website_brief/client_website_brief_screen.dart';
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

const _adminRoutePanels = <String, String>{
  '/admin/leads': 'leads',
  '/admin/consultations': 'clients',
  '/admin/plans': 'plans',
  '/admin/payments': 'payments',
  '/admin/tasks': 'tasks',
  '/admin/sales-tasks': 'salesTasks',
  '/admin/my-tasks': 'myTasks',
  '/admin/my-dashboard': 'myDashboard',
  '/admin/brand-briefs': 'briefs',
  '/admin/website-briefs': 'briefs',
  '/admin/users': 'users',
  '/admin/chat': 'chat',
  '/admin/templates': 'chat',
  '/admin/performance': 'performance',
  '/admin/my-performance': 'myPerformance',
  '/admin/reports': 'tasks',
};

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

    if (!authStateNotifier.hasResolvedInitialState) {
      return location == '/auth-guard' ? null : '/auth-guard';
    }

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
      final profile = await FirebaseAuthService().getUserProfile(user.uid);
      final requiredPanel = _adminRoutePanels.entries
          .where((entry) => location.startsWith(entry.key))
          .map((entry) => entry.value)
          .firstOrNull;
        final allowed = requiredPanel != null &&
          canAccessAdminPanel(profile, requiredPanel);
      if (!allowed) {
        return firstGrantedAdminRoute(profile) ?? '/staff-access';
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
      path: '/admin/sales-tasks',
      builder: (context, state) => const TasksScreen(salesOnly: true),
    ),
    GoRoute(
      path: '/admin/my-tasks',
      builder: (context, state) => const MyAssignedTasksScreen(),
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => const WeeklyReportsScreen(adminMode: true),
    ),
    GoRoute(
      path: '/admin/website-briefs',
      builder: (context, state) => const WebsiteBriefsScreen(),
    ),
    GoRoute(
      path: '/admin/website-briefs/:planId',
      builder: (context, state) =>
          WebsiteBriefReviewScreen(planId: state.pathParameters['planId']!),
    ),
    GoRoute(
      path: '/admin/website-briefs/:planId/edit',
      builder: (context, state) =>
          WebsiteBriefAdminEditScreen(planId: state.pathParameters['planId']!),
    ),
    GoRoute(
      path: '/admin/brand-briefs',
      builder: (context, state) => const BrandBriefsScreen(),
    ),
    GoRoute(
      path: '/admin/brand-briefs/:planId',
      builder: (context, state) =>
          BrandBriefReviewScreen(planId: state.pathParameters['planId']!),
    ),
    GoRoute(
      path: '/admin/brand-briefs/:planId/edit',
      builder: (context, state) =>
          BrandBriefAdminEditScreen(planId: state.pathParameters['planId']!),
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
    GoRoute(
      path: '/client/reports',
      builder: (context, state) => const WeeklyReportsScreen(adminMode: false),
    ),
    GoRoute(
      path: '/client/website-brief',
      builder: (context, state) => const ClientWebsiteBriefScreen(),
    ),
    GoRoute(
      path: '/client/website-brief/:planId',
      builder: (context, state) =>
          ClientWebsiteBriefScreen(planId: state.pathParameters['planId']),
    ),
    GoRoute(
      path: '/client/brand-brief',
      builder: (context, state) => const ClientBrandBriefScreen(),
    ),
    GoRoute(
      path: '/client/brand-brief/:planId',
      builder: (context, state) =>
          ClientBrandBriefScreen(planId: state.pathParameters['planId']),
    ),
  ],
);
