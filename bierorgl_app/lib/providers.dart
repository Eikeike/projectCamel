import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/models/event.dart';
import 'package:project_camel/repositories/event_repository.dart';
import 'package:project_camel/services/auto_sync_controller.dart';
import 'package:project_camel/services/database_helper.dart';
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

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper(); 
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return EventRepository(dbHelper);
});

final allEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.getAllEvents();
});

final eventByIdProvider = FutureProvider.family<Event?, String>((ref, id) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.getEventById(id);
});