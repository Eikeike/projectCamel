import 'dart:async';

import 'package:project_camel/core/constants.dart';
import 'package:project_camel/services/database_helper.dart';
import 'package:project_camel/models/event.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class EventRepository {
  EventRepository(this._db, this._bus);
  final DatabaseHelper _db;
  final StreamController<DbTopic> _bus;

  Future<List<Event>> getAllEvents() async {
    final db = await _db.database;
    final rows = await db.query(
      'Event',
      where: 'localDeletedAt IS NULL',
      orderBy: 'dateFrom DESC',
    );
    return rows.map(Event.fromDb).toList();
    ;
  }

  Future<Event?> getEventById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'Event',
      where: 'eventID = ? AND localDeletedAt IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Event.fromDb(rows.first);
  }

  Future<void> markEventAsDeleted(String eventID) async {
    final db = await _db.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'Event',
      {
        'localDeletedAt': nowIso,
        'syncStatus': SyncStatus.pendingDelete.value,
      },
      where: 'eventID = ?',
      whereArgs: [eventID],
    );
    _bus.add(DbTopic.events);
  }

  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    final db = await _db.database;
    return db.query(
      'Event',
      where: 'syncStatus IN (?, ?, ?)',
      whereArgs: [
        SyncStatus.pendingCreate.value,
        SyncStatus.pendingUpdate.value,
        SyncStatus.pendingDelete.value,
      ],
    );
  }

  Future<List<EventStats>> getTopEventsByUser(
    String userId, {
    int limit = 3,
  }) async {
    final db = await _db.database;

    final res = await db.rawQuery('''
    SELECT
      e.eventID,
      e.name,
      COUNT(s.sessionID) as count,
      COALESCE(SUM(s.volumeML), 0) as totalVol
    FROM Session s
    JOIN Event e ON s.eventID = e.eventID
    WHERE s.userID = ? AND s.localDeletedAt IS NULL AND s.eventID IS NOT NULL
    GROUP BY s.eventID
    ORDER BY count DESC
    LIMIT ?
  ''', [userId, limit]);

    return res.map(EventStats.fromRow).toList();
  }

  Future<void> upsertFromServer(
    Map<String, dynamic> data, {
    DatabaseExecutor? executor,
    bool notify = true,
  }) async {
    final db = executor ?? await _db.database;

    final event = Event.fromServer(data);

    final row = <String, dynamic>{
      ...event.toDb(),
      'localDeletedAt': null,
      'syncStatus': SyncStatus.synced.value,
    };

    await db.insert(
      'Event',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (notify) {
      _bus.add(DbTopic.events);
    }
  }

  Future<void> markSynced(String eventID) async {
    final db = await _db.database;
    await db.update(
      'Event',
      {'syncStatus': SyncStatus.synced.value},
      where: 'eventID = ?',
      whereArgs: [eventID],
    );
  }

  Future<void> saveEventForSync(Event event) async {
    final db = await _db.database;
    final eventID = event.id.isNotEmpty ? event.id : const Uuid().v4();

    final existingRows = await db.query(
      'Event',
      where: 'eventID = ?',
      whereArgs: [eventID],
      limit: 1,
    );

    final row = <String, dynamic>{
      ...event.toDb(), // from your model
      'eventID': eventID,
      'localDeletedAt': null,
    };

    if (existingRows.isEmpty) {
      row['syncStatus'] = SyncStatus.pendingCreate.value;
      await db.insert('Event', row);
    } else {
      final existing = existingRows.first;
      final currentStatus = existing['syncStatus'] as String?;
      final isStillLocalOnly = currentStatus == SyncStatus.pendingCreate.value;

      row['syncStatus'] = isStillLocalOnly
          ? SyncStatus.pendingCreate.value
          : SyncStatus.pendingUpdate.value;

      await db.update(
        'Event',
        row,
        where: 'eventID = ?',
        whereArgs: [eventID],
      );
    }
    _bus.add(DbTopic.events);
  }
}
