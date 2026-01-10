import 'package:flutter/material.dart';

class AppColorConstants {
  AppColorConstants._();

  // --- THEME SEED COLORS (Deine Auswahl) ---
  static const Color ocean = Colors.blue;
  static const Color nature = Colors.green;
  static const Color cherry = Colors.red;
  static const Color royal = Colors.deepPurple;
  static const Color sunset = Colors.orange;
  static const Color coffee = Colors.brown;

  static const ColorScheme legacyScheme = ColorScheme(
    brightness: Brightness.light,

    // 1. Hauptfarben (Brand)
    primary: Color(0xFFF7812B),
    onPrimary: Colors.white, // Weißer Text auf Orange ist gut lesbar
    primaryContainer:
        Color(0xFFFFDCC1), // Ein sehr helles Orange für Boxen-Hintergründe
    onPrimaryContainer: Color(0xFF3E1C00), // Dunkles Braun für Text in Boxen

    // 2. Sekundärfarben (Akzente)
    secondary: Color(0xFFFF9500),
    onSecondary: Colors
        .white, // oder Colors.black, je nach Lesbarkeit. Weiß wirkt sauberer.
    secondaryContainer: Color(0xFFFFE0B2), // Helles Orange-Gelb
    onSecondaryContainer: Color(0xFF2B1700), // Dunkles Braun

    // 3. Tertiärfarben (Für Abwechslung, hier ein warmer Braunton passend zum Orange)
    tertiary: Color(0xFF7A5900),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFDEA5),
    onTertiaryContainer: Color(0xFF261900),

    // 4. Fehlerfarben (Standard Rot, aber etwas wärmer angepasst)
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),

    // 5. Oberflächen & Hintergründe
    // WICHTIG: 'surface' ist oft die Farbe von Cards. Da der Background Creme ist,
    // machen wir die Cards strahlend weiß für den Kontrast (typisch für alte Apps).
    surface: Color(0xFFFFF8F0),
    onSurface: Color(0xFF201A17), // Fast Schwarz, weiches Anthrazit für Text

    // Varianten für Listen-Items oder deaktivierte Elemente
    // Ein leichtes Beige-Grau, passend zum Creme-Hintergrund
    surfaceContainerLowest: Color(0xFFFFF8F0), // 0xFFFFF8F0
    surfaceContainerLow: Color(0xFFFFFCF8),
    surfaceContainer: Colors.white,
    surfaceContainerHigh: Color(0xFFFFF8F5),
    surfaceContainerHighest: Color(0xFFF7F0EB),
    onSurfaceVariant: Color(0xFF52443C), // Dunkles Beige-Grau für Subtitles

    // Rahmenfarbe (Divider, Inputs)
    outline: Color(0xFF85736B),
    outlineVariant: Color(0xFFD7C2B8),

    // Diverse Surface Töne (M3 spezifisch)
    surfaceDim: Color(0xFFE3D8D0),
    surfaceBright: Color(0xFFFFF8F6),

    // Inverse Farben (für Snackbars etc.)
    inverseSurface: Color(0xFF362F2B),
    onInverseSurface: Color(0xFFFBEEE9),
    inversePrimary: Color(0xFFFFB784),

    // Schatten
    shadow: Colors.black,
    scrim: Colors.black,
  );
}
