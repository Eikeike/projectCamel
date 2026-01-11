import 'dart:async';

import 'package:project_camel/core/constants.dart';
import 'package:project_camel/repositories/event_repository.dart';
import 'package:project_camel/repositories/sesion_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../repositories/auth_repository.dart';

class SyncService {
  SyncService({
    required this.authRepository,
    required this.eventRepo,
    required this.sessionRepo,
    //required this.userRepo,
    //required this.metadataRepo,
    required this.bus,
  });

  final AuthRepository authRepository;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  final EventRepository eventRepo;
  final SessionRepository sessionRepo;
  //final UserRepository userRepo;
  //final MetadataRepository metadataRepo;
  final StreamController<DbTopic> bus;

  Future<void> sync() async {
    print("---Enter Sync---");
    await push();
    await pull();
  }

  Future<void> push() async {
    print("---Sync.push---");
    final pendingEvents = await eventRepo.getPendingEvents();
    print("---Sync.push: ${pendingEvents.length} pending events");

    await uploadEvents(pendingEvents);

    final pendingSessions = await sessionRepo.getPendingSessions();
    print("---Sync.push: ${pendingSessions.length} pending sessions");

    await uploadSessions(pendingSessions);
  }

  Future<void> pull() async {
    print("---Sync.pull---");

    //auslagern!
    final currentSeq = await _dbHelper.getCurrentDbSequence();
    print("currentSeq: $currentSeq");

    final response = await authRepository.get(
      '/api/sync/',
      queryParameters: {'since': currentSeq},
    );

    final body = response.data as Map<String, dynamic>;
    final changes = (body['changes'] as List<dynamic>? ?? []);
    final int newSeq = (body['next_cursor'] as int?) ?? currentSeq;

    final changed = <DbTopic>{};
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final dynamic changeRaw in changes) {
        final change = changeRaw as Map<String, dynamic>;
        final String type = change['type'] as String;
        final String op = change['op'] as String;
        final dynamic data = change['data'];
        final String id = change['id'] as String;

        print("Handling change: type=$type, op=$op, id=$id, data=$data");

        // Sicherstellen, dass data ein Map ist
        final Map<String, dynamic>? dataMap =
            data is Map<String, dynamic> ? data : null;

        if (op == 'upsert') {
          final topic = await upsert(type, dataMap, executor: txn);
          if (topic != null) changed.add(topic);
        } else if (op == 'delete') {
          final topic = await delete(type, id, executor: txn);
          if (topic != null) changed.add(topic);
        }
      }

      for (final t in changed) {
        bus.add(t);
      }
      await _dbHelper.setDbSequence(newSeq, executor: txn);
    });
    // print("SYNC: updated dbSequence to $newSeq");
  }

  Future<DbTopic?> upsert(
    String type,
    Map<String, dynamic>? dataMap, {
    DatabaseExecutor? executor,
  }) async {
    switch (type) {
      case 'user':
        if (dataMap != null) {
          await _dbHelper.upsertUserFromServer(dataMap, executor: executor);
          return DbTopic.users;
        } else {
          print("WARN: user change received empty dataMap");
          return null;
        }

      case 'event':
        if (dataMap != null) {
          await eventRepo.upsertFromServer(dataMap,
              executor: executor, notify: false);
          return DbTopic.events;
        } else {
          print("WARN: event change received empty dataMap");
          return null;
        }

      case 'session':
        if (dataMap != null) {
          await sessionRepo.upsertFromServer(dataMap,
              executor: executor, notify: false);
          return DbTopic.sessions;
        } else {
          print("WARN: session change received empty dataMap");
          return null;
        }

      default:
        print("Unknown type: $type");
        return null;
    }
  }

  Future<DbTopic?> delete(
    String type,
    String id, {
    DatabaseExecutor? executor,
  }) async {
    switch (type) {
      case 'user':
        await _dbHelper.syncDeleteUserById(id, executor: executor);
        return DbTopic.users;

      case 'event':
        await _dbHelper.syncDeleteEventById(id, executor: executor);
        return DbTopic.events;

      case 'session':
        await _dbHelper.syncDeleteSessionById(id, executor: executor);
        return DbTopic.sessions;

      default:
        print("Unknown type for delete: $type");
        return null;
    }
  }

  Future<void> uploadEvents(List<Map<String, dynamic>> pendingEvents) async {
    for (final event in pendingEvents) {
      final status = event['syncStatus'] as String?;
      final id = event['eventID'] as String;
      final payload = {
        'id': event['eventID'],
        'name': event['name'],
        'description': event['description'],
        'date_from': event['dateFrom'],
        'date_to': event['dateTo'],
        'latitude': event['latitude'],
        'longitude': event['longitude'],
      };

      try {
        if (status == SyncStatus.pendingCreate.value) {
          final response = await authRepository.post(
            '/api/events/',
            data: payload,
          );
          print("POST event $id -> ${response.statusCode}");
        } else if (status == SyncStatus.pendingUpdate) {
          final response = await authRepository.put(
            '/api/events/$id/',
            data: payload,
          );
          print("PUT event $id -> ${response.statusCode}");
        } else if (status == SyncStatus.pendingDelete.value) {
          final response = await authRepository.delete(
            '/api/events/$id/',
          );
          print("DELETE event $id -> ${response.statusCode}");
        } else {
          print("Unknown event syncStatus: $status");
          continue;
        }

        await eventRepo.markSynced(event['eventID'] as String);
      } catch (e) {
        print("ERROR while pushing event ${event['eventID']}: $e");
        // NICHT auf synced setzen
      }
    }
  }

  Future<void> uploadSessions(
      List<Map<String, dynamic>> pendingSessions) async {
    for (final session in pendingSessions) {
      final status = session['syncStatus'] as String?;
      final id = session['sessionID'] as String;
      final payload = {
        'id': session['sessionID'],
        'name': session['name'],
        'user': session['userID'],
        'event': session['eventID'],
        'values': session['valuesJSON'],
        'volume': session['volumeML'],
        'latitude': session['latitude'],
        'longitude': session['longitude'],
        'started_at': session['startedAt'],
        'duration_ms': session['durationMS'],
        'calibration_factor': session['calibrationFactor'],
        'description': session['description'],
      };

      try {
        if (status == SyncStatus.pendingCreate.value) {
          final response = await authRepository.post(
            '/api/sessions/',
            data: payload,
          );
          print(
              "POST session ${session['sessionID']} -> ${response.statusCode}");
        } else if (status == SyncStatus.pendingUpdate.value) {
          final response = await authRepository.put(
            '/api/sessions/$id/',
            data: payload,
          );
          print("PUT session $id -> ${response.statusCode}");
        } else if (status == SyncStatus.pendingDelete.value) {
          final response = await authRepository.delete(
            '/api/sessions/$id/',
          );
          print("DELETE session $id -> ${response.statusCode}");
        } else {
          print("Unknown session syncStatus: $status");
          continue;
        }
        await _dbHelper.markSessionSynced(session['sessionID'] as String);
      } catch (e) {
        print("ERROR while pushing session ${session['sessionID']}: $e");
      }
    }
  }
}
