import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';
import 'package:project_camel/core/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({super.key});

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _acceptedPrivacy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openPrivacyPolicy() async {
    final ok = await launchUrl(
      Uri.parse(AppConstants.privacyURL),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte Link nicht öffnen')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte akzeptiere die Datenschutzbedingungen.'),
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte E-Mail und Username eingeben')),
      );
      return;
    }

    if (password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bitte Passwort und Bestätigung eingeben')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwörter stimmen nicht überein')),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).register(
          email: email,
          username: username,
          firstName: firstName.isEmpty ? null : firstName,
          lastName: lastName.isEmpty ? null : lastName,
          password: password,
          confirmPassword: confirmPassword,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    InputDecoration deco(String label, {Widget? suffix}) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: suffix,
        );

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: deco('E-Mail'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          decoration: deco('Username'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _firstNameController,
          textInputAction: TextInputAction.next,
          decoration: deco('Vorname (optional)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _lastNameController,
          textInputAction: TextInputAction.next,
          decoration: deco('Nachname (optional)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: !_passwordVisible,
          textInputAction: TextInputAction.next,
          decoration: deco(
            'Passwort',
            suffix: IconButton(
              icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_confirmPasswordVisible,
          textInputAction: TextInputAction.done,
          decoration: deco(
            'Passwort bestätigen',
            suffix: IconButton(
              icon: Icon(_confirmPasswordVisible
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: () => setState(
                  () => _confirmPasswordVisible = !_confirmPasswordVisible),
            ),
          ),
        ),

        // NEW: checkbox + link (Material 3-ish)
        const SizedBox(height: 12),
        MergeSemantics(
          child: CheckboxListTile(
            value: _acceptedPrivacy,
            onChanged: isLoading
                ? null
                : (v) => setState(() => _acceptedPrivacy = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: cs.primary,
            title: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Ich akzeptiere die '),
                  TextSpan(
                    text: 'Datenschutzbedingungen',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: cs.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = _openPrivacyPolicy,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrieren'),
          ),
        ),
      ],
    );
  }
}
