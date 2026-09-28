import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _emailSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(firebaseAuthServiceProvider).sendPasswordResetEmail(email);
      if (mounted) {
        setState(() => _emailSent = true);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found') {
        setState(() => _emailSent = true);
      } else {
        setState(() => _error = _messageFor(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the reset email. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'too-many-requests' =>
      'Too many reset attempts. Wait a few minutes and try again.',
    'network-request-failed' =>
      'Could not connect. Check your internet connection and try again.',
    'operation-not-allowed' =>
      'Password reset is unavailable. Contact your administrator.',
    _ => 'Could not send the reset email. Try again.',
  };

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final at = email.indexOf('@');
    if (at <= 0 ||
        at == email.length - 1 ||
        !email.substring(at).contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _backToLogin() => context.go('/admin/login');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _emailSent
                        ? Icons.mark_email_read_outlined
                        : Icons.lock_reset_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _emailSent ? 'Check your email' : 'Reset your password',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _emailSent
                        ? 'If an account exists for ${_emailController.text.trim()}, a reset link has been sent. Open the link to choose a new password.'
                        : 'Enter your account email. We will send a secure link to choose a new password.',
                    textAlign: TextAlign.center,
                  ),
                  if (!_emailSent) ...[
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _sendResetEmail();
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isLoading ? null : _sendResetEmail,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send reset link'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _backToLogin,
                    child: Text(
                      _emailSent ? 'Return to login' : 'Back to login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
