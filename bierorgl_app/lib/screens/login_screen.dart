import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/screens/password_reset_screen.dart';
import 'package:project_camel/screens/register_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:project_camel/auth/auth_providers.dart';
import 'package:project_camel/services/database_helper.dart';
import 'package:project_camel/widgets/login_form.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _launchURL(BuildContext context) async {
    final Uri url = Uri.parse(
      'https://dev.trichter.biertrinkenistgesund.de/register/',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konnte die URL nicht öffnen: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardHeight > 80; // wichtig!

    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) async {
        if (previous?.userId != next.userId && next.userId != null) {
          try {
            final dbHelper = DatabaseHelper();
            await dbHelper.updateLoggedInUser(next.userId!);
          } catch (_) {}
        }

        if (previous?.errorMessage != next.errorMessage &&
            next.errorMessage != null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(next.errorMessage!)),
            );
          }
        }
      },
    );

    const anim = Duration(milliseconds: 0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: anim,
                height: keyboardOpen ? 20 : 60,
              ),

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

              AnimatedContainer(
                duration: anim,
                height: keyboardOpen ? 16 : 48,
              ),

              Text(
                'BIERORGL',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
              ),

              AnimatedContainer(
                duration: anim,
                height: keyboardOpen ? 6 : 12,
              ),

              Text(
                'Anmelden um fortzufahren',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
              ),

              AnimatedContainer(
                duration: anim,
                height: keyboardOpen ? 20 : 48,
              ),

              const LoginForm(),

              const Spacer(),

              /// Footer: bleibt weg bis Tastatur WIRKLICH weg ist
              /// Footer: bleibt weg bis Tastatur WIRKLICH weg ist
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: keyboardOpen
                    ? const SizedBox.shrink()
                    : Column(
                        key: const ValueKey('footer'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PasswordResetScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'PASSWORT VERGESSEN?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                children: [
                                  const TextSpan(text: 'NOCH KEIN KONTO? '),
                                  TextSpan(
                                    text: 'KONTO ERSTELLEN',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
