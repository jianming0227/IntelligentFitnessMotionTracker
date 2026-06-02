import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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

  Future<void> _handleRegister() async {
    setState(() {
      _emailError = _validateEmail(_emailController.text.trim());
      _passwordError = _validatePassword(_passwordController.text);
      _confirmError = _confirmController.text == _passwordController.text
          ? null
          : 'Passwords do not match';
    });
    if (_emailError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }

    final email = _emailController.text.trim();
    await ref.read(authControllerProvider.notifier).signUp(
          email: email,
          password: _passwordController.text,
        );

    // Supabase's default flow sends a confirmation email and keeps the
    // session null until the link is clicked. Tell the user to go check it.
    if (!mounted) return;
    final hadError = ref.read(authControllerProvider).hasError;
    if (hadError) return;

    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: cs.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confirmation email sent to $email — tap the link to '
                  'activate your account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );

    // Bounce to Login so the user knows where to return after confirming.
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Form(
      key: _formKey,
      child: AuthScaffold(
        activeTab: 'signup',
        heading: const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Hello '),
              TextSpan(
                text: 'newbie',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ','),
            ],
          ),
        ),
        subtitle: 'Enter your information below or sign up with another '
            'account.',
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
            textInputAction: TextInputAction.next,
            errorText: _passwordError,
          ),
          AuthField(
            label: 'Password again',
            controller: _confirmController,
            obscureText: _obscureConfirm,
            isPassword: true,
            onTogglePassword: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            errorText: _confirmError,
          ),
        ],
        primaryLabel: 'Sign up',
        loading: authState.isLoading,
        onPrimary: _handleRegister,
        error: authState.hasError ? authState.error.toString() : null,
      ),
    );
  }
}
