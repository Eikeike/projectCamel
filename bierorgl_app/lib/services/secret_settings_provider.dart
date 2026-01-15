import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Wir nutzen 'Notifier' (Riverpod 2.0+), NICHT StateNotifier.
class SecretSettingsNotifier extends Notifier<bool> {
  static const _key = 'isSecretMenuUnlocked';

  @override
  bool build() {
    // 1. Initialer Zustand ist false
    // 2. Wir starten das Laden im Hintergrund ("Fire and forget")
    _loadState();
    return false;
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedValue = prefs.getBool(_key) ?? false;

    // State aktualisieren, wenn er sich vom initialen Wert unterscheidet
    if (state != loadedValue) {
      state = loadedValue;
    }
  }

  Future<void> unlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = true; // UI aktualisiert sich sofort
  }

  Future<void> lock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = false;
  }
}

// Der Provider Definition
final secretSettingsProvider =
    NotifierProvider<SecretSettingsNotifier, bool>(() {
  return SecretSettingsNotifier();
});
