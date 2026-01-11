import 'dart:async';

import 'package:project_camel/core/constants.dart';
import 'package:project_camel/services/database_helper.dart';
import 'package:project_camel/models/session.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class SessionRepository {
  SessionRepository(this._db, this._bus);

  final DatabaseHelper _db;
  final StreamController<DbTopic> _bus;

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

  Future<List<Session>> getSessionsByUserID(String userID) async {
    final db = await _db.database;

    final rows = await db.rawQuery('''
      SELECT s.*, e.name AS eventName
      FROM Session s
      LEFT JOIN Event e ON s.eventID = e.eventID
      WHERE s.userID = ? 
        AND s.localDeletedAt IS NULL
      ORDER BY s.startedAt DESC
    ''', [userID]);

    return rows.map(Session.fromHistoryRow).toList();
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
    _bus.add(DbTopic.sessions);
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

  Future<void> upsertFromServer(
    Map<String, dynamic> data, {
    DatabaseExecutor? executor,
    bool notify = true,
  }) async {
    final db = executor ?? await _db.database;

    final session = Session.fromServer(data);

    final row = <String, dynamic>{
      ...session.toDb(),
      'localDeletedAt': data[
          'deleted_at'], // or null if you want to clear local deletions on server upsert
      'syncStatus': SyncStatus.synced.value,
    };

    await db.insert(
      'Session',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (notify) {
      _bus.add(DbTopic.sessions);

      // Only emit events if your UI has event-derived-from-sessions queries
      // (session counts per event, event “has sessions” state, etc.)
      if (session.eventID != null) {
        _bus.add(DbTopic.events);
      }
    }
  }

  Future<void> saveLocalSession(Session session) async {
    final db = await _db.database;
    await db.insert(
      'Session',
      session.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _bus.add(DbTopic.sessions);
  }

  Future<void> saveSessionForSync(
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
      await db.insert(
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
      await db.insert('Session', row);
    }

    final existing = existingRows.first;
    final currentStatus = existing['syncStatus'] as String?;

    if (currentStatus == SyncStatus.pendingCreate.value) {
      row['syncStatus'] = SyncStatus.pendingCreate.value;
    } else {
      row['syncStatus'] = SyncStatus.pendingUpdate.value;
    }

    await db.update(
      'Session',
      row,
      where: 'sessionID = ?',
      whereArgs: [sessionID],
    );
    _bus.add(DbTopic.sessions);
  }
}
