import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({super.key});

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final _formKey = GlobalKey<FormState>();

  // FocusNodes für die Scroll-Steuerung
  final _emailFocus = FocusNode();
  final _userFocus = FocusNode();
  final _fNameFocus = FocusNode();
  final _lNameFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confFocus = FocusNode();

  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Listener für jedes Feld hinzufügen
    _setupScrollListener(_emailFocus);
    _setupScrollListener(_userFocus);
    _setupScrollListener(_fNameFocus);
    _setupScrollListener(_lNameFocus);
    _setupScrollListener(_passFocus);
    _setupScrollListener(_confFocus);
  }

  void _setupScrollListener(FocusNode node) {
    node.addListener(() {
      if (node.hasFocus) {
        // Kurze Verzögerung, damit die Tastatur hochfahren kann
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          Scrollable.ensureVisible(
            node.context!,
            duration: const Duration(milliseconds: 10),
            curve: Curves.easeOutExpo,
            alignment:
                0.5, // 0.5 bedeutet: Feld in die Mitte des sichtbaren Bereichs
          );
        });
      }
    });
  }

  @override
  void dispose() {
    // Alles sauber aufräumen
    _emailFocus.dispose();
    _userFocus.dispose();
    _fNameFocus.dispose();
    _lNameFocus.dispose();
    _passFocus.dispose();
    _confFocus.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          firstName: _firstNameController.text.trim().isEmpty
              ? null
              : _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim().isEmpty
              ? null
              : _lastNameController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        );
  }

  InputDecoration _deco(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffix,
      );

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _deco('E-Mail'),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'E-Mail erforderlich' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            focusNode: _userFocus,
            textInputAction: TextInputAction.next,
            decoration: _deco('Username'),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Username erforderlich' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  focusNode: _fNameFocus,
                  textInputAction: TextInputAction.next,
                  decoration: _deco('Vorname'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  focusNode: _lNameFocus,
                  textInputAction: TextInputAction.next,
                  decoration: _deco('Nachname'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            focusNode: _passFocus,
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.next,
            decoration: _deco(
              'Passwort',
              suffix: IconButton(
                icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Min. 6 Zeichen' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            focusNode: _confFocus,
            obscureText: !_confirmPasswordVisible,
            textInputAction: TextInputAction.done,
            decoration: _deco(
              'Passwort bestätigen',
              suffix: IconButton(
                icon: Icon(_confirmPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () => setState(
                    () => _confirmPasswordVisible = !_confirmPasswordVisible),
              ),
            ),
            validator: (v) =>
                v != _passwordController.text ? 'Passwörter ungleich' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('REGISTRIEREN',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
