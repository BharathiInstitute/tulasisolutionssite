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
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final canDelete =
        ref.watch(currentUserProfileProvider).valueOrNull?.isAdmin == true;

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
              final isSelf =
                  user.uid == currentUser?.uid ||
                  user.email.toLowerCase() == currentUser?.email?.toLowerCase();
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
                      if (canDelete)
                        IconButton(
                          tooltip: 'Delete staff',
                          onPressed: isSelf || user.isAdmin
                              ? null
                              : () =>
                                    _showDeleteStaffDialog(context, ref, user),
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
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
        error: (error, stackTrace) => CustomErrorWidget(
          message: 'Error loading users: $error',
          onRetry: () => ref.invalidate(allUsersProvider),
        ),
      ),
    );
  }

  Future<void> _showDeleteStaffDialog(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final confirmationController = TextEditingController();
    var deleting = false;
    String? errorMessage;
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !deleting,
            child: AlertDialog(
              title: const Text('Delete staff?'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user.name}\n${user.email}'),
                      const SizedBox(height: 12),
                      const Text(
                        'This permanently deletes the staff login and linked '
                        'profiles. Task history is kept. This cannot be undone.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmationController,
                        autofocus: true,
                        enabled: !deleting,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Type DELETE to confirm',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: confirmationController,
                  builder: (context, value, child) => FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(deleting ? 'Deleting...' : 'Delete'),
                    onPressed: deleting || value.text != 'DELETE'
                        ? null
                        : () async {
                            setDialogState(() {
                              deleting = true;
                              errorMessage = null;
                            });
                            try {
                              await ref
                                  .read(firestoreServiceProvider)
                                  .deleteStaffMember(user.uid, value.text);
                              ref.invalidate(allUsersProvider);
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${user.name} deleted'),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  deleting = false;
                                  errorMessage =
                                      'Could not delete staff: $error';
                                });
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      confirmationController.dispose();
    }
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
            password: details.password,
            role: details.role,
            team: details.team,
            panels: details.panels,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff login created successfully')),
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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final roleController = TextEditingController(text: user?.role ?? '');
    final panels = {...defaultStaffPanels, ...?user?.panels};
    final teams = {...teamOptions};
    String? selectedTeam = user?.team;
    if (selectedTeam?.isEmpty ?? true) selectedTeam = null;

    try {
      return await showDialog<_StaffDetails>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(user == null ? 'Add staff' : 'Edit staff'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        enabled: user == null,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) =>
                            value == null ||
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value.trim())
                            ? 'Enter a valid email'
                            : null,
                      ),
                      if (user == null) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Use at least 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          validator: (value) => value != passwordController.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                      ],
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
                          onChanged: defaultStaffPanels.contains(panel.key)
                              ? null
                              : (selected) {
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
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  context.pop(
                    _StaffDetails(
                      name: name,
                      email: email,
                      password: passwordController.text,
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
    } finally {
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
      roleController.dispose();
    }
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
  final String password;
  final String role;
  final String team;
  final List<String> panels;

  const _StaffDetails({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.team,
    required this.panels,
  });
}
