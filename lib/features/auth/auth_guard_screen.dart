import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/access/panel_access.dart';

/// Splash/Auth Guard Screen
/// Checks user authentication status and admin role, then routes accordingly
class AuthGuardScreen extends ConsumerWidget {
  const AuthGuardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        // Not logged in - go to login
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profileAsync = ref.watch(currentUserProfileStreamProvider);
        return profileAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Scaffold(
            body: Center(
              child: Text('Error checking staff access: $error'),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Staff access required. Contact an administrator to request access.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(firstGrantedAdminRoute(profile) ?? '/staff-access');
            });

            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Authentication Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StaffAccessRequiredScreen extends ConsumerWidget {
  const StaffAccessRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Staff access required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account has not been added to the staff panel. Contact an administrator to request access.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/admin/my-dashboard'),
                icon: const Icon(Icons.refresh),
                label: const Text('Check access'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(firebaseAuthServiceProvider)
                    .signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
