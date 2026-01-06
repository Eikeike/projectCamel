import 'package:flutter/material.dart';



    // const backgroundColor = Color(0xFFFFF8F0);
    // const accentOrange = Color(0xFFFF9500);
    // const accentBlue = Color(0xFF2196F3);
class AppColors {
  //static const primary = Color.fromARGB(255, 0, 251, 255);// helles blau, garnicht verkehrt
  static const primary = Color.fromARGB(255, 132, 0, 255);// lila, garnicht verkehrt
  
  
  //static const primary = Color.fromARGB(255, 255, 0, 212); 

  //static const primary = Color.fromARGB(255, 8, 21, 52); 
  static const primaryDark = Color(0xFFFFC166);

  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;

  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);

  static const error = Colors.redAccent;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

// class AppTheme {
//   static ThemeData get light {
//     final base = ColorScheme.fromSeed(
//       seedColor: AppColors.primary,
//       brightness: Brightness.light,
//     );

//     final scheme = base.copyWith(
//       primary: AppColors.primary,
//     );

//     return ThemeData(
//       useMaterial3: true,
//       colorScheme: scheme,
//     );
//   }

//   static ThemeData get dark {
//     final base = ColorScheme.fromSeed(
//       seedColor: AppColors.primaryDark,
//       brightness: Brightness.dark,
//     );

//     final scheme = base.copyWith(
//       primary: AppColors.primaryDark,
//     );

//     return ThemeData(
//       useMaterial3: true,
//       colorScheme: scheme,
//     );
//   }
// }

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.primary,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.primary,
      );
}

// class AppTheme {
//   static ThemeData light(ColorScheme scheme) {
//     return ThemeData(
//       useMaterial3: true,
//       colorScheme: scheme,
//     );
//   }

//   static ThemeData dark(ColorScheme scheme) {
//     return ThemeData(
//       useMaterial3: true,
//       colorScheme: scheme,
//     );
//   }
// }
