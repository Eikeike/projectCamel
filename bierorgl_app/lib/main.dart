import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- PROJEKT IMPORTS ---
// Passe diese Pfade an deine Struktur an, falls nötig
import 'providers.dart'; // Hier sollte dein autoSyncControllerProvider sein
import 'auth/auth_providers.dart'; // Hier ist dein authControllerProvider
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/device_selection_screen.dart';

// Core & Theme Imports
import 'theme/theme_provider.dart';
import 'core/color_constants.dart'; // WICHTIG: Deine neuen Farben

void main() async {
  // 1. Flutter Engine initialisieren
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Speicher (SharedPrefs) laden BEVOR die App startet
  final prefs = await SharedPreferences.getInstance();

  // 3. Orientierung auf Portrait festlegen (optional, aber für Bier-Apps meist sinnvoll)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 4. App starten
  runApp(
    ProviderScope(
      // Hier injizieren wir die geladene Instanz in unseren Provider
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
    // Hintergrund-Controller am Leben erhalten
    final autoSyncController = ref.watch(autoSyncControllerProvider);

    // Theme State beobachten (Modus, SeedColor, LegacyMode)
    final themeState = ref.watch(themeProvider);

    // --- THEME LOGIK ---
    ThemeData themeData;
    ThemeMode themeMode;
    ThemeData? darkThemeData;

    if (themeState.isLegacyMode) {
      // =======================================================
      // MODUS 1: LEGACY / ALPHA (Retro Look)
      // =======================================================
      // Zwinge Light Mode, da die alte App keinen Dark Mode hatte
      themeMode = ThemeMode.light;

      themeData = ThemeData(
        useMaterial3: true,
        // Nutze das handgebaute Schema aus AppColorConstants
        colorScheme: AppColorConstants.legacyScheme,

        // WICHTIG: Hintergrund auf das Creme-Weiß setzen (surface im legacyScheme)
        scaffoldBackgroundColor: AppColorConstants.legacyScheme.surface,

        // AppBar passend zum Retro-Look (transparent oder creme)
        appBarTheme: AppBarTheme(
          backgroundColor: AppColorConstants.legacyScheme.surface,
          surfaceTintColor:
              Colors.transparent, // Entfernt den M3 Farbschleier beim Scrollen
          iconTheme:
              IconThemeData(color: AppColorConstants.legacyScheme.primary),
          titleTextStyle: TextStyle(
            color: AppColorConstants.legacyScheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      // Im Legacy Modus gibt es kein separates Dark Theme
      darkThemeData = null;
    } else {
      // =======================================================
      // MODUS 2: MODERN (Material 3 Standard)
      // =======================================================
      themeMode = themeState.mode;

      // Helles Design (Modern)
      themeData = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeState.seedColor,
          brightness: Brightness.light,
        ),
      );

      // Dunkles Design (Modern)
      darkThemeData = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeState.seedColor,
          brightness: Brightness.dark,
        ),
      );
    }

    return MaterialApp(
      title: 'Bierorgl App',
      debugShowCheckedModeBanner: false,

      // --- THEME KONFIGURATION ---
      themeMode: themeMode,
      theme: themeData,
      darkTheme: darkThemeData,

      // --- NAVIGATION ---
      home: AuthGate(autoSyncController: autoSyncController),
      routes: {
        '/bluetooth': (context) => const DeviceSelectionScreen(),
      },
    );
  }
}

// Diese Klasse regelt den Zugriff (Login vs. Home)
class AuthGate extends ConsumerWidget {
  final dynamic autoSyncController;
  const AuthGate({super.key, required this.autoSyncController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    // 1. Ladezustand prüfen
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. Nicht eingeloggt? -> Login Screen
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    // 3. Eingeloggt? -> Home Screen
    return HomeScreen(autoSyncController: autoSyncController);
  }
}
