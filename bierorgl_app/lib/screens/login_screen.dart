import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final authState = ref.watch(authControllerProvider);

    // Listen for auth state changes:
    // - when userId becomes non-null, write it to the local DB
    // - when errorMessage changes, show a SnackBar
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) async {
        // Authenticated → store logged-in user in Metadata table
        if (previous?.userId != next.userId && next.userId != null) {
          try {
            final dbHelper = DatabaseHelper();
            await dbHelper.updateLoggedInUser(next.userId!);
            // ignore: avoid_print
            print(
              "DATABASE DEBUG: LoggedInUserID auf ${next.userId} gesetzt.",
            );
          } catch (e) {
            // ignore: avoid_print
            print(
              "DATABASE ERROR: Fehler beim Setzen der LoggedInUserID: $e",
            );
          }
          // No manual navigation here:
          // AuthGate in main.dart will rebuild and show HomeScreen.
        }

        // Show error messages
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

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB366).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/Logo_ohneText.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.local_bar,
                      size: 120,
                      color: Color(0xFFFF8C42),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Bierorgl',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8C42),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Willkommen zurück',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB366).withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: LoginForm(
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => _launchURL(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
                child: const Text(
                  'Noch keinen Account? Jetzt registrieren',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
