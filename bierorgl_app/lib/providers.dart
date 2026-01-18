import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/models/event.dart';
import 'package:project_camel/models/session.dart';
import 'package:project_camel/repositories/event_repository.dart';
import 'package:project_camel/repositories/sesion_repository.dart';
import 'package:project_camel/services/auto_sync_controller.dart';
import 'package:project_camel/services/database_helper.dart';
import 'package:project_camel/services/sync_service.dart';
import 'package:project_camel/auth/auth_providers.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    authRepository: ref.read(authRepositoryProvider),
    eventRepo: ref.read(eventRepositoryProvider),
    sessionRepo: ref.read(sessionRepositoryProvider),
    //userRepo: ref.read(userRepositoryProvider),
    //metadataRepo: ref.read(metadataRepositoryProvider),
    bus: ref.read(dbChangeBusProvider),
  );
});

final autoSyncControllerProvider = Provider<AutoSyncController>((ref) {
  final syncService = ref.read(syncServiceProvider); //oder ref.watch
  final controller = AutoSyncController(syncService, ref);
  ref.onDispose(controller.disable);
  return controller;
});

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// --- Event ---

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final bus = ref.watch(dbChangeBusProvider);
  return EventRepository(dbHelper, bus);
});

final allEventsProvider = StreamProvider<List<Event>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery(
    bus: bus.stream,
    topic: DbTopic.events,
    query: repo.getAllEvents,
  );
});

final eventByIdProvider = StreamProvider.family<Event?, String>((ref, id) {
  final repo = ref.watch(eventRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery(
    bus: bus.stream,
    topic: DbTopic.events,
    query: () => repo.getEventById(id),
  );
});

final topEventsByUserProvider =
    StreamProvider.family<List<EventStats>, String>((ref, userId) {
  final repo = ref.watch(eventRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQueryMulti(
    bus: bus.stream,
    topics: {DbTopic.sessions, DbTopic.events},
    query: () => repo.getTopEventsByUser(userId, limit: 3),
  );
});

// --- User ---
final userByIdProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery<Map<String, dynamic>?>(
    bus: bus.stream,
    topic: DbTopic.users,
    query: () => dbHelper.getUserByID(userId),
  );
});

/// --- Session ---

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final bus = ref.watch(dbChangeBusProvider);
  return SessionRepository(dbHelper, bus);
});

final allSessionsProvider = StreamProvider<List<Session>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: repo.getAllSessions,
  );
});

final sessionByIdProvider = StreamProvider.family<Session?, String>((ref, id) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: () => repo.getSessionById(id),
  );
});

final sessionsByUserIDProvider =
    StreamProvider.family<List<Session>, String>((ref, userID) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery<List<Session>>(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: () => repo.getSessionsByUserID(userID),
  );
});

final sessionsByEventIDProvider =
    StreamProvider.family<List<Session>, String>((ref, eventID) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery<List<Session>>(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: () => repo.getSessionsByEventID(eventID),
  );
});

typedef LeaderboardParams = ({
  Set<String>? userIDs,
  int? volumeML,
  String? eventID,
  LeaderboardSort sort,
  int? limit,
  int? offset,
});

final leaderboardSessionsProvider =
    StreamProvider.family<List<Session>, LeaderboardParams>((ref, params) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery<List<Session>>(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: () => repo.getLeaderboardSessions(
      userIDs: params.userIDs,
      volumeML: params.volumeML,
      eventID: params.eventID,
      sort: params.sort,
      limit: params.limit,
      offset: params.offset,
    ),
  );
});

final leaderboardTotalVolumeProvider =
    StreamProvider.family<List<AggregatedLeaderboardEntry>, LeaderboardParams>(
        (ref, params) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery<List<AggregatedLeaderboardEntry>>(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: () => repo.getLeaderboardTotalVolume(
      userIDs: params.userIDs,
      eventID: params.eventID,
    ),
  );
});

final leaderboardSessionCountProvider =
    StreamProvider.family<List<AggregatedLeaderboardEntry>, LeaderboardParams>(
        (ref, params) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery<List<AggregatedLeaderboardEntry>>(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: () => repo.getSessionCountAgg(
      userIDs: params.userIDs,
      eventID: params.eventID,
    ),
  );
});

final leaderboardAvgSecondsPerLiterProvider =
    StreamProvider.family<List<AggregatedLeaderboardEntry>, LeaderboardParams>(
        (ref, params) {
  final repo = ref.watch(sessionRepositoryProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery<List<AggregatedLeaderboardEntry>>(
    bus: bus.stream,
    topic: DbTopic.sessions,
    query: () => repo.getUserSecondsPerLiter(
      userIDs: params.userIDs,
      eventID: params.eventID,
    ),
  );
});

// --- Users (list from DB) ---
final usersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final bus = ref.watch(dbChangeBusProvider);

  return watchQuery(
    bus: bus.stream,
    topic: DbTopic.users,
    query: dbHelper.getUsers,
  );
});

// --- UI state: volume filter ---
enum VolumeFilter { all, koelsch, l033, l05 }

class VolumeFilterNotifier extends Notifier<VolumeFilter> {
  @override
  VolumeFilter build() => VolumeFilter.all;

  void setFilter(VolumeFilter filter) {
    state = filter;
  }
}

final volumeFilterProvider =
    NotifierProvider<VolumeFilterNotifier, VolumeFilter>(
  VolumeFilterNotifier.new,
);
