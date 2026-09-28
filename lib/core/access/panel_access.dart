import '../models/models.dart';

const adminPanelRoutes = <String, String>{
    'leads': '/admin/leads',
    'clients': '/admin/consultations',
    'payments': '/admin/payments',
    'tasks': '/admin/tasks',
    'myDashboard': '/admin/my-dashboard',
    'myTasks': '/admin/my-tasks',
    'users': '/admin/users',
    'chat': '/admin/chat',
    'performance': '/admin/performance',
    'myPerformance': '/admin/my-performance',
};

const _adminRoutePanels = <String, String>{
    '/admin/leads': 'leads',
    '/admin/consultations': 'clients',
    '/admin/payments': 'payments',
    '/admin/tasks': 'tasks',
    '/admin/reports': 'tasks',
    '/admin/my-dashboard': 'myDashboard',
    '/admin/my-tasks': 'myTasks',
    '/admin/users': 'users',
    '/admin/chat': 'chat',
    '/admin/templates': 'chat',
    '/admin/performance': 'performance',
    '/admin/my-performance': 'myPerformance',
};

String? panelForAdminRoute(String route) => _adminRoutePanels[route];

/// Central panel authorization policy for staff and administrator accounts.
bool canAccessAdminPanel(AppUser? profile, String panel) =>
    profile?.isAdmin == true || profile?.canAccessPanel(panel) == true;

bool hasGrantedAdminPanel(AppUser? profile) =>
    profile?.isAdmin == true ||
    (profile?.isStaff == true && profile!.panels.isNotEmpty);

String? firstGrantedAdminRoute(AppUser? profile) {
    if (!hasGrantedAdminPanel(profile)) return null;
    if (profile?.isAdmin == true) return '/admin/dashboard';
    for (final entry in adminPanelRoutes.entries) {
        if (canAccessAdminPanel(profile, entry.key)) return entry.value;
    }
    return null;
}
