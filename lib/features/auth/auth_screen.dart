import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/brand_logo.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(firebaseAuthServiceProvider);
      await auth.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _returnToWebsite() {
    return launchUrl(
      Uri.parse('https://tulasisolutions.com'),
      mode: LaunchMode.platformDefault,
    );
  }

  InputDecoration _fieldDecoration(String hintText) {
    const borderGrey = Color(0xFFE0E0E0);
    const brandGreen = Color(0xFF3AB32A);

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF6B7268)),
      filled: true,
      fillColor: const Color(0xFFF7F8F5),
      contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: brandGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF8A3A3A)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF3AB32A);
    const deepGreen = Color(0xFF0F6B3A);
    const charcoal = Color(0xFF1A1F1B);

    return Scaffold(
      backgroundColor: charcoal,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [charcoal, Color(0xFF142A1D), deepGreen],
                  stops: [0, 0.68, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -90,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 340,
                height: 260,
                color: brandGreen.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -80,
            child: Transform.rotate(
              angle: -0.3,
              child: Container(
                width: 380,
                height: 260,
                color: brandGreen.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x240F6B3A),
                                    blurRadius: 44,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Center(
                                        child: BrandLogo(height: 92),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        'Admin Login',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          height: 1.15,
                                          color: charcoal,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Welcome back. Sign in to continue.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF6B7268),
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: _fieldDecoration('Email'),
                                        validator: (value) =>
                                            value == null ||
                                                !value.contains('@')
                                            ? 'Enter a valid email'
                                            : null,
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: true,
                                        decoration: _fieldDecoration(
                                          'Password',
                                        ),
                                        validator: (value) =>
                                            value == null || value.length < 6
                                            ? 'Use at least 6 characters'
                                            : null,
                                      ),
                                      if (_errorMessage != null) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 28),
                                      SizedBox(
                                        height: 58,
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: brandGreen,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor:
                                                const Color(0xFF9BCF92),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                              : const Text(
                                                  'Sign in',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () => context.push(
                                                '/forgot-password',
                                              ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: deepGreen,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 30),
                                        ),
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _returnToWebsite,
                                        style: TextButton.styleFrom(
                                          foregroundColor: deepGreen,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 30),
                                        ),
                                        child: const Text(
                                          'Back to website',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Center(
                          child: Text(
                            'Secure access to your Tulasi Solutions account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xBFFFFFFF),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
