import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:project_camel/auth/auth_providers.dart';
import 'package:project_camel/widgets/unauthed/password_reset_form.dart';

class PasswordResetScreen extends ConsumerWidget {
  const PasswordResetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardHeight > 80;

    // Optional: listen for errors/success from your auth controller
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.errorMessage != next.errorMessage &&
            next.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.errorMessage!)),
          );
        }

        // If you add a "resetEmailSent" flag/state later, you can show success here.
      },
    );

    const anim = Duration(milliseconds: 0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        //title: const Text('Passwort vergessen?'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(duration: anim, height: keyboardOpen ? 20 : 60),
              AnimatedContainer(
                duration: anim,
                height: keyboardOpen ? 0 : 150,
                child: Opacity(
                  opacity: keyboardOpen ? 0 : 1,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      'assets/images/Logo_ohneText.png',
                      width: 150,
                      height: 150,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(duration: anim, height: keyboardOpen ? 16 : 48),
              Text(
                'PASSWORT VERGESSEN?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
              ),
              AnimatedContainer(duration: anim, height: keyboardOpen ? 6 : 12),
              Text(
                'Gib deine E-Mail ein, wir senden dir einen Link.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
              ),
              AnimatedContainer(duration: anim, height: keyboardOpen ? 20 : 48),
              const PasswordResetForm(),
              const Spacer(),
              AnimatedContainer(
                duration: anim,
                height: keyboardOpen ? 0 : 72,
                child: Opacity(
                  opacity: keyboardOpen ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: keyboardOpen,
                    child: Column(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Zurück zum Login',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
