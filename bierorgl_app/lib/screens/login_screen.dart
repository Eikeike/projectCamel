import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cubits/auth_cubit.dart';
import '../widgets/login_form.dart';
import '../services/database_helper.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _launchURL(BuildContext context) async {
    final Uri url = Uri.parse('https://dev.trichter.biertrinkenistgesund.de/register/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konnte die URL nicht öffnen: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E6),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) async {
          if (state is AuthAuthenticated) {
            // --- HIER IST DIE LOGIK ---
            // DatabaseHelper Instanz holen und die UserID in die DB schreiben
            try {
              final dbHelper = DatabaseHelper();
              await dbHelper.updateLoggedInUser(state.userId);
              print("DATABASE DEBUG: LoggedInUserID auf ${state.userId} gesetzt.");
            } catch (e) {
              print("DATABASE ERROR: Fehler beim Setzen der LoggedInUserID: $e");
              // Optional: Dem User eine Fehlermeldung zeigen
            }
            // --------------------------

            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }

          } else if (state is AuthError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Center(
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
                      return Icon(
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
                  child: const LoginForm(),
                ),
                const SizedBox(height: 24),
                // Der 'Jetzt registrieren'-Button bleibt erhalten.
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
      ),
    );
  }
}