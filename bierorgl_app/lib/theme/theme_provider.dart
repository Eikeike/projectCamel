import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/color_constants.dart'; // Pfad ggf. anpassen, falls die Datei anders heißt

// 1. Ein Platzhalter-Provider für SharedPrefs
// Dieser wird in der main.dart überschrieben (dependency injection)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// 2. Der State (Daten-Klasse)
class AppThemeState {
  final ThemeMode mode;
  final Color seedColor;
  final bool isLegacyMode;

  const AppThemeState({
    required this.mode,
    required this.seedColor,
    this.isLegacyMode = false, // Standardmäßig aus
  });

  AppThemeState copyWith({
    ThemeMode? mode,
    Color? seedColor,
    bool? isLegacyMode,
  }) {
    return AppThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
      isLegacyMode: isLegacyMode ?? this.isLegacyMode,
    );
  }
}

// 3. Der Notifier (Logik)
class ThemeNotifier extends Notifier<AppThemeState> {
  // Schlüssel für die Datenbank
  static const _keyThemeMode = 'theme_mode';
  static const _keySeedColor = 'seed_color';
  static const _keyLegacyMode = 'theme_legacy_mode';

  @override
  AppThemeState build() {
    // Wir holen uns die Instanz von SharedPrefs
    final prefs = ref.watch(sharedPreferencesProvider);

    // --- LADEN ---

    // 1. Modus laden
    final savedModeString = prefs.getString(_keyThemeMode);
    ThemeMode mode = ThemeMode.system;
    if (savedModeString != null) {
      mode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedModeString,
        orElse: () => ThemeMode.system,
      );
    }

    // 2. Farbe laden
    final savedColorInt = prefs.getInt(_keySeedColor);
    // Fallback auf Ocean oder Blue, falls AppColorConstants nicht gefunden wird
    Color seedColor = AppColorConstants.ocean;
    if (savedColorInt != null) {
      seedColor = Color(savedColorInt);
    }

    // 3. Legacy Mode laden (NEU)
    final savedLegacy = prefs.getBool(_keyLegacyMode) ?? false;

    return AppThemeState(
      mode: mode,
      seedColor: seedColor,
      isLegacyMode: savedLegacy,
    );
  }

  // --- SPEICHERN ---

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color);
    ref.read(sharedPreferencesProvider).setInt(_keySeedColor, color.value);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    ref
        .read(sharedPreferencesProvider)
        .setString(_keyThemeMode, mode.toString());
  }

  // NEU: Legacy Mode umschalten
  void setLegacyMode(bool isActive) {
    state = state.copyWith(isLegacyMode: isActive);
    ref.read(sharedPreferencesProvider).setBool(_keyLegacyMode, isActive);
  }
}

// 4. Der Provider für die UI
final themeProvider = NotifierProvider<ThemeNotifier, AppThemeState>(() {
  return ThemeNotifier();
});
