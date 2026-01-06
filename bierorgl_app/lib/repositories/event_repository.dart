import 'package:project_camel/core/constants.dart';
import 'package:project_camel/services/database_helper.dart';
import 'package:project_camel/models/event.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class EventRepository {
  final DatabaseHelper _db;

  EventRepository(this._db);

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

  Future<void> upsertEventFromServer(Map<String, dynamic> data) async {
    final db = await _db.database;

    final row = <String, dynamic>{
      'eventID': data['id'],
      'name': data['name'],
      'description': data['description'],
      'dateFrom': data['date_from'],
      'dateTo': data['date_to'],
      'latitude': (data['latitude'] as num?)?.toDouble(),
      'longitude': (data['longitude'] as num?)?.toDouble(),
      'localDeletedAt': null,
      'syncStatus': SyncStatus.synced.value,
    };

    await db.insert(
      'Event',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> saveEventForSync(Event event) async {
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
      return db.insert('Event', row);
    } else {
      final existing = existingRows.first;
      final currentStatus = existing['syncStatus'] as String?;
      final isStillLocalOnly = currentStatus == SyncStatus.pendingCreate.value;

      row['syncStatus'] = isStillLocalOnly
          ? SyncStatus.pendingCreate.value
          : SyncStatus.pendingUpdate.value;

      return db.update(
        'Event',
        row,
        where: 'eventID = ?',
        whereArgs: [eventID],
      );
    }
  }
}
