import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/auth/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart'; // WICHTIG: Importieren

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/device_selection_screen.dart';

import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. SharedPreferences VOR dem App-Start laden
  final prefs = await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    ProviderScope(
      // 2. Hier injizieren wir die geladenen Prefs in unseren Provider
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoSyncControllerProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Bierorgl App',
      debugShowCheckedModeBanner: false,

      // Theme Modus
      themeMode: themeState.mode,

      // Helles Design
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeState.seedColor,
          brightness: Brightness.light,
        ),
      ),

      // Dunkles Design
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeState.seedColor,
          brightness: Brightness.dark,
        ),
      ),

      home: const AuthGate(),
      routes: {
        '/bluetooth': (context) => const DeviceSelectionScreen(),
      },
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final autoSyncController = ref.watch(autoSyncControllerProvider);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    return HomeScreen(autoSyncController: autoSyncController);
  }
}
