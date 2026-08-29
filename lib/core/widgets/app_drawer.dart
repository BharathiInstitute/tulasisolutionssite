import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/constants/test_access.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/theme/app_theme.dart';
import 'package:tulasisolutionssite/core/widgets/brand_logo.dart';

/// Breakpoint above which the side menu is shown as a permanent panel
/// instead of a hamburger-triggered drawer.
const double kDesktopBreakpoint = 900;

/// Scaffold wrapper that shows [AppDrawer] as a permanent side panel on
/// wide (desktop/tablet) screens, and as a normal hamburger drawer on
/// narrow (mobile) screens.
class AppShell extends StatelessWidget {
  final bool isAdmin;
  final String currentRoute;
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  const AppShell({
    super.key,
    required this.isAdmin,
    required this.currentRoute,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 260,
                child: AppDrawer(
                  isAdmin: isAdmin,
                  currentRoute: currentRoute,
                  permanent: true,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(title),
                    backgroundColor: Colors.green,
                    actions: actions,
                    bottom: bottom,
                  ),
                  floatingActionButton: floatingActionButton,
                  body: body,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green,
        actions: actions,
        bottom: bottom,
      ),
      drawer: AppDrawer(isAdmin: isAdmin, currentRoute: currentRoute),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

class AppDrawer extends ConsumerWidget {
  final bool isAdmin;
  final String currentRoute;
  final bool permanent;

  const AppDrawer({
    super.key,
    required this.isAdmin,
    required this.currentRoute,
    this.permanent = false,
  });

  void _navigate(BuildContext context, String route) {
    if (!permanent) Navigator.of(context).pop();
    if (currentRoute != route) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthServiceProvider).getCurrentUser();
    final title = isAdmin ? 'Admin Panel' : 'Client Portal';
    final email = user?.email ?? '';
    final clientId = GoRouter.of(context).state.pathParameters['clientId'];
    final clientAsync = clientId != null && clientId.isNotEmpty
        ? ref.watch(clientProvider(clientId))
        : const AsyncValue<Client?>.data(null);
    final clientName = clientAsync.valueOrNull?.name.trim();

    final content = SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.deepGreen, AppTheme.brandGreen],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const BrandLogo(height: 48, compact: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (clientName != null && clientName.isNotEmpty)
                            ? clientName
                            : email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isAdmin) ...[
            _item(
              context,
              icon: Icons.people,
              label: 'Leads',
              route: '/admin/leads',
            ),
            _item(
              context,
              icon: Icons.event,
              label: 'Clients',
              route: '/admin/consultations',
            ),
            _item(
              context,
              icon: Icons.receipt_long_outlined,
              label: 'Plans',
              route: '/admin/plans',
            ),
            _item(
              context,
              icon: Icons.payments_outlined,
              label: 'Payments',
              route: '/admin/payments',
            ),
            _item(
              context,
              icon: Icons.task_alt,
              label: 'Tasks',
              route: '/admin/tasks',
            ),
            _item(
              context,
              icon: Icons.admin_panel_settings,
              label: 'User Management',
              route: '/admin/users',
            ),
            _item(
              context,
              icon: Icons.chat,
              label: 'Chat',
              route: '/admin/chat',
            ),
          ] else ...[
            _item(
              context,
              icon: Icons.dashboard,
              label: 'Dashboard',
              route: '/client/dashboard',
            ),
            _item(
              context,
              icon: Icons.flag,
              label: 'My Goals',
              route: '/client/goals',
            ),
            _item(
              context,
              icon: Icons.task_alt,
              label: 'My Tasks',
              route: '/client/tasks',
            ),
          ],
          if (dualPanelTestEmails.contains(email.toLowerCase()))
            _item(
              context,
              icon: Icons.swap_horiz,
              label: isAdmin ? 'Client Panel' : 'Admin Panel',
              route: isAdmin ? '/client/dashboard' : '/admin/leads',
            ),
          _item(
            context,
            icon: Icons.manage_accounts,
            label: 'Account details',
            route: '/account-details',
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              if (!permanent) Navigator.of(context).pop();
              await ref.read(firebaseAuthServiceProvider).signOut();
            },
          ),
        ],
      ),
    );

    if (permanent) {
      return Material(
        color: Theme.of(context).canvasColor,
        elevation: 1,
        child: content,
      );
    }

    return Drawer(child: content);
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final selected = currentRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        selected: selected,
        leading: Icon(icon, color: selected ? AppTheme.deepGreen : null),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: () => _navigate(context, route),
      ),
    );
  }
}
