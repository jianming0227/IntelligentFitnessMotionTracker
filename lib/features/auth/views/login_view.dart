import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/demo_mode_provider.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    // Re-render heading whenever the email field changes so the "Julietta"
    // bold-name swap reflects what the user types.
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() => setState(() {});

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String v) {
    if (v.isEmpty) return 'Email is required';
    if (!v.contains('@')) return 'You have entered an invalid email address!';
    return null;
  }

  String? _validatePassword(String v) {
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Min 6 characters';
    return null;
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = _validateEmail(_emailController.text.trim());
      _passwordError = _validatePassword(_passwordController.text);
    });
    if (_emailError != null || _passwordError != null) return;

    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  String _firstNameFromEmail() {
    final raw = _emailController.text.trim();
    if (raw.isEmpty || !raw.contains('@')) return '';
    final handle = raw.split('@').first;
    if (handle.isEmpty) return '';
    return handle[0].toUpperCase() + handle.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final name = _firstNameFromEmail();

    return Form(
      key: _formKey,
      child: AuthScaffold(
        activeTab: 'login',
        heading: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Welcome back,\n'),
              TextSpan(
                text: name.isEmpty ? 'athlete' : name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        subtitle: 'Sign in to pick up where you left off and keep your '
            'streak alive.',
        fields: [
          AuthField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            hint: 'you@example.com',
            errorText: _emailError,
          ),
          AuthField(
            label: 'Password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            isPassword: true,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
            errorText: _passwordError,
          ),
        ],
        primaryLabel: 'Login',
        loading: authState.isLoading,
        onPrimary: _handleLogin,
        error: authState.hasError ? authState.error.toString() : null,
        demoOnTap: () async {
          await seedDemoData();
          ref.read(demoModeProvider.notifier).state = true;
          // ignore: use_build_context_synchronously
          context.go('/home');
        },
      ),
    );
  }
}
