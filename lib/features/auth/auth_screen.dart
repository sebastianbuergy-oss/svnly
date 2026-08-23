import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../app/providers.dart';
import '../../core/config/build_identity.dart';
import '../../core/design/tokens.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/widgets/brand.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialSignUp = false});
  final bool initialSignUp;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  late bool signUp;
  bool loading = false;
  bool verificationSent = false;

  @override
  void initState() {
    super.initState();
    signUp = widget.initialSignUp;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final repository = ref.read(appRepositoryProvider);
      if (signUp) {
        await repository.signUp(email.text, password.text);
        if (mounted) setState(() => verificationSent = true);
      } else {
        await repository.signIn(email.text, password.text);
        final complete = await repository.hasCompletedProfile();
        if (mounted) context.go(complete ? '/home' : '/profile-setup');
      }
    } catch (error, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.authMessage('email', error, stackTrace)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _apple() async {
    setState(() => loading = true);
    try {
      final repository = ref.read(appRepositoryProvider);
      await repository.signInWithApple();
      final complete = await repository.hasCompletedProfile();
      if (mounted) context.go(complete ? '/home' : '/profile-setup');
    } catch (error, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.authMessage('apple', error, stackTrace)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => loading = true);
    try {
      final repository = ref.read(appRepositoryProvider);
      final sessionReady = repository.sessionChanges
          .firstWhere((hasSession) => hasSession)
          .timeout(const Duration(minutes: 3));
      await repository.signInWithGoogle();
      await sessionReady;
      final complete = await repository.hasCompletedProfile();
      if (mounted) context.go(complete ? '/home' : '/profile-setup');
    } catch (error, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.authMessage('google', error, stackTrace)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      minimum: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const SvnlyWordmark(fontSize: 38),
              const SizedBox(height: 40),
              Text(
                verificationSent
                    ? 'Check your inbox.'
                    : signUp
                    ? 'Join the real ones.'
                    : 'Welcome back.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                verificationSent
                    ? 'We sent a secure verification link to ${email.text}.'
                    : 'Your seven seconds are waiting.',
                style: const TextStyle(color: SvnlyColors.secondaryText),
              ),
              if (!verificationSent) ...[
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    key: const ValueKey('auth_google'),
                    onPressed: loading ? null : _google,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    label: const Text('CONTINUE WITH GOOGLE'),
                  ),
                ),
                const SizedBox(height: 12),
                SignInWithAppleButton(
                  key: const ValueKey('auth_apple'),
                  onPressed: loading ? () {} : _apple,
                  height: 54,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  style: SignInWithAppleButtonStyle.white,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
                TextFormField(
                  key: const ValueKey('auth_email'),
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value != null && value.contains('@')
                      ? null
                      : 'Enter a valid email.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('auth_password'),
                  controller: password,
                  obscureText: true,
                  autofillHints: [
                    signUp ? AutofillHints.newPassword : AutofillHints.password,
                  ],
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) => (value?.length ?? 0) >= 10
                      ? null
                      : 'Use at least 10 characters.',
                ),
                if (!signUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey('auth_submit'),
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(signUp ? 'CREATE ACCOUNT' : 'LOG IN'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => signUp = !signUp),
                  child: Text(
                    signUp ? 'I already have an account' : 'Create an account',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  BuildIdentity.label,
                  key: const ValueKey('build_identity'),
                  style: const TextStyle(
                    color: SvnlyColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      verificationSent = false;
                      signUp = false;
                    }),
                    child: const Text('BACK TO LOG IN'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends ConsumerState<ForgotPasswordScreen> {
  final email = TextEditingController();
  bool sent = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      minimum: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: sent
                ? null
                : () async {
                    await ref
                        .read(appRepositoryProvider)
                        .resetPassword(email.text);
                    if (mounted) setState(() => sent = true);
                  },
            child: Text(sent ? 'LINK SENT' : 'SEND RESET LINK'),
          ),
        ],
      ),
    ),
  );
}
