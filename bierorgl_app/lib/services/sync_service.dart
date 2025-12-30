import 'database_helper.dart';
import '../repositories/auth_repository.dart';

class SyncService {
  final AuthRepository authRepository;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  SyncService({required this.authRepository});

  Future<void> sync() async {
    print("---Enter Sync---");
    await push();
    await pull();
  }

  Future<void> push() async {
    print("---Sync.push---");
    final pendingEvents = await _dbHelper.getPendingEvents();
    print("---Sync.push: ${pendingEvents.length} pending events");

    await uploadEvents(pendingEvents);

    final pendingSessions = await _dbHelper.getPendingSessions();
    print("---Sync.push: ${pendingSessions.length} pending sessions");

    await uploadSessions(pendingSessions);

  }

  Future<void> pull() async {
    print("---Sync.pull---");

    final currentSeq  = 1;//= await _dbHelper.getCurrentDbSequence();
    print("currentSeq: $currentSeq");

    final response = await authRepository.get(
      '/api/sync/',
      queryParameters: {'since': currentSeq},
    );

    final body = response.data as Map<String, dynamic>;
    //print("BODY: $body");

    final changes = (body['changes'] as List<dynamic>? ?? []);
    final int newSeq = (body['next_cursor'] as int?) ?? currentSeq;

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
        await upsert(type, dataMap);
      } else if (op == 'delete') {
        await delete(type, id);
      } else {
        print("Unknown op: $op");
      }
    }

    await _dbHelper.setDbSequence(newSeq);

    final currentSeq2 = await _dbHelper.getCurrentDbSequence();
    print(currentSeq2);
    // print("SYNC: updated dbSequence to $newSeq");
  }

  Future<void> upsert(type, dataMap) async {
    switch (type) {
      case 'user':
        if (dataMap != null) {
          print("upsert user: $dataMap");
          await _dbHelper.upsertUserFromServer(dataMap);
        } else {
          print("WARN: user change received empty dataMap");
        }
        break;
      case 'event':
        if (dataMap != null) {
          await _dbHelper.upsertEventFromServer(dataMap);
        } else {
          print("WARN: event change received empty dataMap");
        }
        break;
      case 'session':
        if (dataMap != null) {
          await _dbHelper.upsertSessionFromServer(dataMap);
        } else {
          print("WARN: session change received empty dataMap");
        }
        break;
      default:
        print("Unknown type: $type");
    }
  }

  Future<void> delete(type, id) async {
    print("---Enter delete---");
    switch (type) {
      case 'user':
        await _dbHelper.syncDeleteUserById(id);
        break;
      case 'event':
        await _dbHelper.syncDeleteEventById(id);
        break;
      case 'session':
        await _dbHelper.syncDeleteSessionById(id);
        break;
      default:
        print("Unknown type for delete: $type");
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
        if (status == 'PENDING_CREATE') {
          final response = await authRepository.post(
            '/api/events/',
            data: payload,
          );
          print("POST event $id -> ${response.statusCode}");
        } else if (status == 'PENDING_UPDATE') {
          final response = await authRepository.put(
            '/api/events/$id/',
            data: payload,
          );
          print("PUT event $id -> ${response.statusCode}");
        } else if(status == 'PENDING_DELETE'){
          final response = await authRepository.delete(
            '/api/events/$id/',
          );
          print("DELETE event $id -> ${response.statusCode}");
        } else {
          print("Unknown event syncStatus: $status");
          continue;
        }

        await _dbHelper.markEventSynced(event['eventID'] as String);
      } catch (e) {
        print("ERROR while pushing event ${event['eventID']}: $e");
        // NICHT auf synced setzen
      }
    }
  }

  Future<void> uploadSessions(List<Map<String, dynamic>> pendingSessions) async {
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
        'description': session['description'],
      };

      try {
        if (status == 'PENDING_CREATE') {
          final response = await authRepository.post(
            '/api/sessions/',
            data: payload,
          );
          print("POST session ${session['sessionID']} -> ${response.statusCode}");
        } else if (status == 'PENDING_UPDATE') {
          final response = await authRepository.put(
            '/api/sessions/$id/',
            data: payload,
          );
          print("PUT session $id -> ${response.statusCode}");
        } else if(status == 'PENDING_DELETE'){
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
