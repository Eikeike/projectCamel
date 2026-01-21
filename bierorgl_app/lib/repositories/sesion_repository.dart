import 'dart:async';

import 'package:project_camel/core/constants.dart';
import 'package:project_camel/services/database_helper.dart';
import 'package:project_camel/models/session.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

enum LeaderboardSort { fastest, slowest, newest, oldest }

extension LeaderboardSortSql on LeaderboardSort {
  String get orderBySql => switch (this) {
        LeaderboardSort.fastest => 's.durationMS ASC',
        LeaderboardSort.slowest => 's.durationMS DESC',
        LeaderboardSort.newest => 's.startedAt DESC',
        LeaderboardSort.oldest => 's.startedAt ASC',
      };
}

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

  Future<List<Session>> getSessionsByEventID(String eventID) async {
    final db = await _db.database;

    final rows = await db.rawQuery('''
      SELECT s.*, e.name AS eventName
      FROM Session s
      LEFT JOIN Event e ON s.eventID = e.eventID
      WHERE s.eventID = ? 
        AND s.localDeletedAt IS NULL
      ORDER BY s.startedAt DESC
    ''', [eventID]);

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

//Leaderboard

  Future<List<Session>> getLeaderboardSessions({
    Set<String>? userIDs,
    int? volumeML,
    String? eventID,
    LeaderboardSort sort = LeaderboardSort.fastest,
    int? limit,
    int? offset,
  }) async {
    final db = await _db.database;

    final where = <String>['s.localDeletedAt IS NULL'];
    final args = <Object?>[];

    // Multi-select users: WHERE s.userID IN (?, ?, ...)
    final normalizedUserIDs =
        (userIDs ?? {}).where((e) => e.isNotEmpty).toSet();
    if (normalizedUserIDs.isNotEmpty) {
      final placeholders = List.filled(normalizedUserIDs.length, '?').join(',');
      where.add('s.userID IN ($placeholders)');
      args.addAll(normalizedUserIDs);
    }

    if (volumeML != null) {
      where.add('s.volumeML = ?');
      args.add(volumeML);
    }

    if (eventID != null && eventID.isNotEmpty) {
      where.add('s.eventID = ?');
      args.add(eventID);
    }

    final sql = StringBuffer()
      ..writeln('SELECT')
      ..writeln('  s.*,')
      ..writeln('  u.username AS username,')
      ..writeln("  u.firstname AS firstname,")
      ..writeln("  u.lastname AS lastname,")
      ..writeln('  e.name AS eventName')
      ..writeln('FROM Session s')
      ..writeln('JOIN User u ON u.userID = s.userID')
      ..writeln('LEFT JOIN Event e ON e.eventID = s.eventID')
      ..writeln('WHERE ${where.join(' AND ')}')
      ..writeln('ORDER BY ${sort.orderBySql}');

    if (limit != null) {
      sql.writeln('LIMIT ?');
      args.add(limit);
      if (offset != null) {
        sql.writeln('OFFSET ?');
        args.add(offset);
      }
    }

    final rows = await db.rawQuery(sql.toString(), args);
    return rows.map(Session.fromLeaderboardRow).toList(growable: false);
  }

  Future<List<AggregatedLeaderboardEntry>> getUserSecondsPerLiter({
    Set<String>? userIDs,
    String? eventID,
    int? volumeML,
  }) async {
    final db = await _db.database;

    final where = <String>['s.localDeletedAt IS NULL'];
    final args = <Object?>[];

    // Multi-select users
    final normalizedUserIDs =
        (userIDs ?? {}).where((e) => e.isNotEmpty).toSet();
    if (normalizedUserIDs.isNotEmpty) {
      final placeholders = List.filled(normalizedUserIDs.length, '?').join(',');
      where.add('s.userID IN ($placeholders)');
      args.addAll(normalizedUserIDs);
    }

    // Filter by event
    if (eventID != null && eventID.isNotEmpty) {
      where.add('s.eventID = ?');
      args.add(eventID);
    }

    if (volumeML != null) {
      where.add('s.volumeML = ?');
      args.add(volumeML);
    }

    final sql = '''
      SELECT s.userID, u.username, 
      AVG(CAST(s.durationMS AS FLOAT) / (CAST(s.volumeML AS FLOAT) / 1000.0)) as value
      FROM Session s
      JOIN User u ON s.userID = u.userID
      WHERE ${where.join(' AND ')}
      GROUP BY s.userID
      ORDER BY value ASC
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows
        .asMap()
        .entries
        .map(
          (entry) => AggregatedLeaderboardEntry.fromDb(
            entry.value,
            userIdKey: 'userID',
            usernameKey: 'username',
            valueKey: 'value',
            rankKey: 'rank',
          ).copyWithRank(entry.key + 1),
        )
        .toList();
  }

  Future<List<AggregatedLeaderboardEntry>> getSessionCountAgg({
    Set<String>? userIDs,
    String? eventID,
    int? volumeML,
  }) async {
    final db = await _db.database;

    final where = <String>['s.localDeletedAt IS NULL'];
    final args = <Object?>[];

    // Multi-select users
    final normalizedUserIDs =
        (userIDs ?? {}).where((e) => e.isNotEmpty).toSet();
    if (normalizedUserIDs.isNotEmpty) {
      final placeholders = List.filled(normalizedUserIDs.length, '?').join(',');
      where.add('s.userID IN ($placeholders)');
      args.addAll(normalizedUserIDs);
    }

    // Filter by event
    if (eventID != null && eventID.isNotEmpty) {
      where.add('s.eventID = ?');
      args.add(eventID);
    }

    if (volumeML != null) {
      where.add('s.volumeML = ?');
      args.add(volumeML);
    }

    final sql = '''
      SELECT s.userID, u.username,
      COUNT(s.sessionID) as value
      FROM Session s
      JOIN User u ON s.userID = u.userID
      WHERE ${where.join(' AND ')}
      GROUP BY s.userID
      ORDER BY value DESC
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows
        .asMap()
        .entries
        .map(
          (entry) => AggregatedLeaderboardEntry.fromDb(
            entry.value,
            userIdKey: 'userID',
            usernameKey: 'username',
            valueKey: 'value',
            rankKey: 'rank',
          ).copyWithRank(entry.key + 1),
        )
        .toList();
  }

  Future<List<AggregatedLeaderboardEntry>> getLeaderboardTotalVolume(
      {Set<String>? userIDs, String? eventID, int? volumeML}) async {
    final db = await _db.database;

    final where = <String>['s.localDeletedAt IS NULL'];
    final args = <Object?>[];

    // Multi-select users
    final normalizedUserIDs =
        (userIDs ?? {}).where((e) => e.isNotEmpty).toSet();
    if (normalizedUserIDs.isNotEmpty) {
      final placeholders = List.filled(normalizedUserIDs.length, '?').join(',');
      where.add('s.userID IN ($placeholders)');
      args.addAll(normalizedUserIDs);
    }

    // Filter by event
    if (eventID != null && eventID.isNotEmpty) {
      where.add('s.eventID = ?');
      args.add(eventID);
    }
    if (volumeML != null) {
      print("TTTTIIIIIM $volumeML");
      where.add('s.volumeML = ?');
      args.add(volumeML);
    }

    final sql = '''
      SELECT s.userID, u.username,
      SUM(s.volumeML) as value
      FROM Session s
      JOIN User u ON s.userID = u.userID
      WHERE ${where.join(' AND ')}
      GROUP BY s.userID
      ORDER BY value DESC
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows
        .asMap()
        .entries
        .map(
          (entry) => AggregatedLeaderboardEntry.fromDb(
            entry.value,
            userIdKey: 'userID',
            usernameKey: 'username',
            valueKey: 'value',
            rankKey: 'rank',
          ).copyWithRank(entry.key + 1),
        )
        .toList();
  }
}
