import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NEU für Orientierung
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cubits/auth_cubit.dart';
import 'repositories/auth_repository.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/device_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // NEU

  // Erlaube beide Orientierungen
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final authRepository = AuthRepository();
  runApp(ProviderScope(child: MyApp(authRepository: authRepository)));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;

  const MyApp({super.key, required this.authRepository});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(authRepository),
      child: MaterialApp(
        title: 'Bierorgl App',
        initialRoute: '/login',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/bluetooth': (context) => const DeviceSelectionScreen(),
        },
      ),
    );
  }
}
