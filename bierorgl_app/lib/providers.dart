import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/services/auto_sync_controller.dart';
import 'package:project_camel/services/sync_service.dart';
import 'package:project_camel/auth/auth_providers.dart';



final syncServiceProvider = Provider<SyncService>((ref) {
  final authRepo = ref.read(authRepositoryProvider);//oder ref.watch?
  return SyncService(authRepository: authRepo);
});

final autoSyncControllerProvider = Provider<AutoSyncController>((ref) {
  final syncService = ref.read(syncServiceProvider); //oder ref.watch
  final controller = AutoSyncController(syncService, ref);
  return controller;
});
