import 'package:project_camel/core/constants.dart';
import 'package:project_camel/services/database_helper.dart';
import 'package:project_camel/models/session.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class SessionRepository {
  final DatabaseHelper _db;

  SessionRepository(this._db);

  /// non-deleted sessions, newest first
  Future<List<Session>> getAllSessions() async {
    final db = await _db.database;
    final rows = await db.query(
      'Session',
      where: 'localDeletedAt IS NULL',
      orderBy: 'startedAt DESC',
    );
    return rows.map(Session.fromSessionRow).toList();
  }

  Future<Session?> getSessionById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'Session',
      where: 'sessionID = ? AND localDeletedAt IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Session.fromSessionRow(rows.first);
  }

  Future<void> markSessionAsDeleted(String sessionID) async {
    final db = await _db.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'Session',
      {
        'localDeletedAt': nowIso,
        'syncStatus': SyncStatus.pendingDelete.value,
      },
      where: 'sessionID = ?',
      whereArgs: [sessionID],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSessions() async {
    final db = await _db.database;
    return db.query(
      'Session',
      where: 'syncStatus IN (?, ?, ?)',
      whereArgs: [
        SyncStatus.pendingCreate.value,
        SyncStatus.pendingUpdate.value,
        SyncStatus.pendingDelete.value,
      ],
    );
  }

  Future<void> upsertSessionFromServer(Map<String, dynamic> data) async {
    final db = await _db.database;

    final row = <String, dynamic>{
      'sessionID': data['id'],
      'volumeML': (data['volume'] as num?)?.toInt(),
      'name': data['name'],
      'description': data['description'],
      'latitude': (data['latitude'] as num?)?.toDouble(),
      'longitude': (data['longitude'] as num?)?.toDouble(),
      'startedAt': data['started_at'],
      'userID': data['user'],
      'eventID': data['event'],
      'durationMS': (data['duration_ms'] as num?)?.toInt(),
      'valuesJSON': data['values']?.toString(),
      'calibrationFactor': (data['calibration_factor'] as num?)?.toInt(),
      'localDeletedAt': data['deleted_at'],
      'syncStatus': SyncStatus.synced.value,
    };

    await db.insert(
      'Session',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> saveLocalSession(Session session) async {
    final db = await _db.database;
    return db.insert(
      'Session',
      session.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> saveSessionForSync(
    Session session, {
    bool isEditing = false,
  }) async {
    final db = await _db.database;
    final sessionID = session.id.isNotEmpty ? session.id : const Uuid().v4();

    final row = <String, dynamic>{
      ...session.toDb(),
      'sessionID': sessionID,
      'localDeletedAt': null,
    };

    if (!isEditing) {
      row['syncStatus'] = SyncStatus.pendingCreate.value;
      return db.insert(
        'Session',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final existingRows = await db.query(
      'Session',
      where: 'sessionID = ?',
      whereArgs: [sessionID],
      limit: 1,
    );

    if (existingRows.isEmpty) {
      // Fallback: treat as create
      row['syncStatus'] = SyncStatus.pendingCreate.value;
      return db.insert('Session', row);
    }

    final existing = existingRows.first;
    final currentStatus = existing['syncStatus'] as String?;

    if (currentStatus == SyncStatus.pendingCreate.value) {
      row['syncStatus'] = SyncStatus.pendingCreate.value;
    } else {
      row['syncStatus'] = SyncStatus.pendingUpdate.value;
    }

    return db.update(
      'Session',
      row,
      where: 'sessionID = ?',
      whereArgs: [sessionID],
    );
  }
}
