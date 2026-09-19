import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final currentUid = ref
        .watch(firebaseAuthServiceProvider)
        .getCurrentUser()
        ?.uid;

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/users',
      title: 'Staff Management',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add staff',
        onPressed: () => _showAddStaffDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No registered users yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              final isSelf = user.uid == currentUid;
              return Card(
                child: ListTile(
                  leading: Icon(
                    user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: user.isAdmin ? Colors.green : Colors.grey,
                  ),
                  title: Text(user.name.isEmpty ? user.email : user.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.email),
                      if (user.role.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.role,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (user.team.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Branch / team: ${user.team}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (user.panels.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            user.panels
                                .map(
                                  (panel) => adminPanelLabels[panel] ?? panel,
                                )
                                .join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit staff permissions',
                        onPressed: () =>
                            _showEditStaffDialog(context, ref, user),
                        icon: const Icon(Icons.manage_accounts_outlined),
                      ),
                      Switch(
                        value: user.isAdmin,
                        onChanged: isSelf
                            ? null
                            : (value) =>
                                  _confirmAndToggle(context, ref, user, value),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading users: $error'),
      ),
    );
  }

  Future<void> _showAddStaffDialog(BuildContext context, WidgetRef ref) async {
    final details = await _showStaffDialog(
      context,
      teamOptions: _teamOptions(ref),
    );
    if (details == null) return;

    try {
      await ref
          .read(firestoreServiceProvider)
          .addStaffMember(
            name: details.name,
            email: details.email,
            role: details.role,
            team: details.team,
            panels: details.panels,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff added successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding staff: $e')));
      }
    }
  }

  Future<void> _showEditStaffDialog(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final details = await _showStaffDialog(
      context,
      user: user,
      teamOptions: _teamOptions(ref, currentTeam: user.team),
    );
    if (details == null) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateStaffMember(
            uid: user.uid,
            name: details.name,
            role: details.role,
            team: details.team,
            panels: details.panels,
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating staff: $error')));
      }
    }
  }

  Future<_StaffDetails?> _showStaffDialog(
    BuildContext context, {
    AppUser? user,
    required List<String> teamOptions,
  }) async {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final roleController = TextEditingController(text: user?.role ?? '');
    final panels = {...?user?.panels};
    final teams = {...teamOptions};
    String? selectedTeam = user?.team;
    if (selectedTeam?.isEmpty ?? true) selectedTeam = null;

    return showDialog<_StaffDetails>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Add staff' : 'Edit staff'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    enabled: user == null,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedTeam,
                          decoration: const InputDecoration(
                            labelText: 'Branch / team',
                          ),
                          hint: const Text('Select branch or team'),
                          items: teams
                              .map(
                                (team) => DropdownMenuItem(
                                  value: team,
                                  child: Text(team),
                                ),
                              )
                              .toList(),
                          onChanged: (team) {
                            setDialogState(() => selectedTeam = team);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add branch or team',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          final team = await _showAddTeamDialog(context);
                          if (team == null || team.isEmpty) return;
                          setDialogState(() {
                            teams.add(team);
                            selectedTeam = team;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    teams.isEmpty
                        ? 'No branches or teams yet. Add one to assign it.'
                        : 'Select an existing branch or team, or add a new one.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Panel permissions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final panel in adminPanelLabels.entries)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(panel.value),
                      value: panels.contains(panel.key),
                      onChanged: (selected) {
                        setDialogState(() {
                          selected == true
                              ? panels.add(panel.key)
                              : panels.remove(panel.key);
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || email.isEmpty) return;
                context.pop(
                  _StaffDetails(
                    name: name,
                    email: email,
                    role: roleController.text.trim(),
                    team: selectedTeam ?? '',
                    panels: panels.toList()..sort(),
                  ),
                );
              },
              child: Text(user == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _teamOptions(WidgetRef ref, {String? currentTeam}) {
    final teams =
        ref
            .read(allUsersProvider)
            .valueOrNull
            ?.map((user) => user.team.trim())
            .where((team) => team.isNotEmpty)
            .toSet() ??
        <String>{};
    if (currentTeam?.trim().isNotEmpty ?? false) {
      teams.add(currentTeam!.trim());
    }
    return teams.toList()..sort();
  }

  Future<String?> _showAddTeamDialog(BuildContext context) async {
    final controller = TextEditingController();
    final team = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add branch or team'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Branch / team name'),
          onSubmitted: (value) => context.pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    return team;
  }

  Future<void> _confirmAndToggle(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    bool makeAdmin,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(makeAdmin ? 'Grant admin access?' : 'Revoke admin access?'),
        content: Text(
          makeAdmin
              ? '${user.email} will be able to manage all clients.'
              : '${user.email} will lose access to the admin panel.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(firestoreServiceProvider)
          .setUserAdminStatus(user.uid, makeAdmin);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating user: $e')));
      }
    }
  }
}

class _StaffDetails {
  final String name;
  final String email;
  final String role;
  final String team;
  final List<String> panels;

  const _StaffDetails({
    required this.name,
    required this.email,
    required this.role,
    required this.team,
    required this.panels,
  });
}
