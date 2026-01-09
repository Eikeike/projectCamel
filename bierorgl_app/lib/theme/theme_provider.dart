import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/core/constants.dart';
//import 'package:project_camel/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';

// 1. Ein Platzhalter-Provider für SharedPrefs
// Dieser wird in der main.dart überschrieben (dependency injection)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// 2. Der State (Daten-Klasse) - Unverändert
class AppThemeState {
  final ThemeMode mode;
  final Color seedColor;

  const AppThemeState({
    required this.mode,
    required this.seedColor,
  });

  AppThemeState copyWith({ThemeMode? mode, Color? seedColor}) {
    return AppThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

// 3. Der Notifier (Logik)
class ThemeNotifier extends Notifier<AppThemeState> {
  // Schlüssel für die Datenbank
  static const _keyThemeMode = 'theme_mode';
  static const _keySeedColor = 'seed_color';

  @override
  AppThemeState build() {
    // Wir holen uns die Instanz von SharedPrefs
    final prefs = ref.watch(sharedPreferencesProvider);

    // --- LADEN ---

    // 1. Modus laden (als String gespeichert, z.B. "ThemeMode.dark")
    final savedModeString = prefs.getString(_keyThemeMode);
    ThemeMode mode = ThemeMode.system;
    if (savedModeString != null) {
      mode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedModeString,
        orElse: () => ThemeMode.system,
      );
    }

    // 2. Farbe laden (als int gespeichert)
    final savedColorInt = prefs.getInt(_keySeedColor);
    Color seedColor = AppColors.ocean;
    if (savedColorInt != null) {
      seedColor = Color(savedColorInt);
    }

    return AppThemeState(
      mode: mode,
      seedColor: seedColor,
    );
  }

  // --- SPEICHERN ---

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color);
    // In Datenbank schreiben
    ref.read(sharedPreferencesProvider).setInt(_keySeedColor, color.value);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    // In Datenbank schreiben
    ref
        .read(sharedPreferencesProvider)
        .setString(_keyThemeMode, mode.toString());
  }
}

// 4. Der Provider für die UI
final themeProvider = NotifierProvider<ThemeNotifier, AppThemeState>(() {
  return ThemeNotifier();
});
