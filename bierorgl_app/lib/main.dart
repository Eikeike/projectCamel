import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NEU für Orientierung
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/services/auto_sync_controller.dart';
import 'package:project_camel/services/sync_service.dart';
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
  final syncService = SyncService(authRepository: authRepository);
  final autoSyncController = AutoSyncController(syncService);

  runApp(ProviderScope(
      child: MyApp(
          authRepository: authRepository,
          autoSyncController: autoSyncController)));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final AutoSyncController autoSyncController;

  const MyApp({super.key, required this.authRepository, required this.autoSyncController});

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
          '/home': (context) =>  HomeScreen(autoSyncController: autoSyncController,),
          '/bluetooth': (context) => const DeviceSelectionScreen(),
        },
      ),
    );
  }
}
