import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  ConsumerState<AccountDetailsScreen> createState() =>
      _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(firebaseAuthServiceProvider).getCurrentUser();
    _emailController.text = user?.email ?? '';
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      setState(() => _error = 'Name and email are required');
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
      _error = null;
    });
    try {
      await ref
          .read(firebaseAuthServiceProvider)
          .updateAccountDetails(
            name: _nameController.text,
            email: _emailController.text,
            newPassword: _passwordController.text.isEmpty
                ? null
                : _passwordController.text,
          );
      if (mounted) {
        setState(() {
          _passwordController.clear();
          _message = 'Account details updated';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(currentUserIsAdminProvider);
    return isAdminAsync.when(
      data: (isAdmin) => AppShell(
        isAdmin: isAdmin,
        currentRoute: '/account-details',
        title: 'Account details',
        body: _buildForm(),
      ),
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (error, stackTrace) => Scaffold(
        body: CustomErrorWidget(message: 'Error loading account: $error'),
      ),
    );
  }

  Widget _buildForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Changing email or password may require a recent sign-in.',
              ),
              if (_message != null)
                Text(_message!, style: const TextStyle(color: Colors.green)),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
