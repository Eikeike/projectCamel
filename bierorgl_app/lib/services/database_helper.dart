import 'package:project_camel/core/constants.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'bierorglDB.db');

    // Prüfen, ob die Datei existiert, BEVOR sqflite sie öffnet
    bool exists = await databaseExists(path);
    print("DATABASE DEBUG: Pfad ist $path");
    print("DATABASE DEBUG: Existiert die Datei? $exists");

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. USER TABELLE
    await db.execute('''
      CREATE TABLE User (
        userID TEXT PRIMARY KEY,
        firstname TEXT,
        lastname TEXT,
        username TEXT,
        eMail TEXT,
        bio TEXT,
        localDeletedAt TEXT,
        syncStatus TEXT
      )
    ''');

    // 2. EVENT TABELLE
    await db.execute('''
      CREATE TABLE Event (
        eventID TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        dateFrom TEXT,
        dateTo TEXT,
        latitude REAL,
        longitude REAL,
        localDeletedAt TEXT,
        syncStatus TEXT
      )
    ''');

    // 3. SESSION TABELLE
    await db.execute('''
      CREATE TABLE Session (
        sessionID TEXT PRIMARY KEY,
        volumeML INTEGER,
        name TEXT,
        description TEXT,
        latitude REAL,
        longitude REAL,
        startedAt TEXT,
        userID TEXT,
        eventID TEXT,
        durationMS INTEGER,
        valuesJSON TEXT,
        calibrationFactor INTEGER,
        localDeletedAt TEXT,
        syncStatus TEXT,
        FOREIGN KEY (userID) REFERENCES User (userID) ON DELETE CASCADE,
        FOREIGN KEY (eventID) REFERENCES Event (eventID) ON DELETE CASCADE
      )
    ''');

    // 4. METADATA TABELLE
    await db.execute('''
      CREATE TABLE Metadata (
        dbSequence INTEGER DEFAULT 0,
        loggedInUserID TEXT
      )
    ''');

    await db.insert('Metadata', {
      'dbSequence': 0,
      'loggedInUserID': null,
    });

    print("DATABASE CREATED: Finales Schema erstellt.");
  }

  // --- CRUD METHODEN ---

  Future<int> insertUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.insert('User', user);
  }

  Future<int> insertEvent(Map<String, dynamic> event) async {
    Database db = await database;
    return await db.insert('Event', event);
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    Database db = await database;
    return await db.insert('Session', session);
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    Database db = await database;
    return await db.query('Event', where: 'localDeletedAt IS NULL');
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    Database db = await database;
    return await db.query('User', where: 'localDeletedAt IS NULL');
  }

  // --- PROFILE & USER HELPERS ---

  Future<Map<String, dynamic>?> getUserByID(String userID) async {
    Database db = await database;
    var res = await db.query('User', where: 'userID = ?', whereArgs: [userID]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getUserStats(String userID,
      {int? volumeML}) async {
    Database db = await database;
    if (volumeML != null) {
      return await db.query('Session',
          where: 'userID = ? AND volumeML = ? AND localDeletedAt IS NULL',
          whereArgs: [userID, volumeML]);
    }
    return await db.query('Session',
        where: 'userID = ? AND localDeletedAt IS NULL', whereArgs: [userID]);
  }

  Future<Map<String, dynamic>?> getMostFrequentEvent(String userID) async {
    Database db = await database;
    var res = await db.rawQuery('''
      SELECT e.name, COUNT(s.sessionID) as count, SUM(s.volumeML) as totalVol
      FROM Session s
      JOIN Event e ON s.eventID = e.eventID
      WHERE s.userID = ? AND s.localDeletedAt IS NULL
      GROUP BY s.eventID
      ORDER BY count DESC
      LIMIT 1
    ''', [userID]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getHistory(String userID) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT s.*, e.name as eventName
      FROM Session s
      LEFT JOIN Event e ON s.eventID = e.eventID
      WHERE s.userID = ? AND s.localDeletedAt IS NULL
      ORDER BY s.startedAt DESC
    ''', [userID]);
  }

  // --- METADATA HELPERS ---

  Future<void> updateLoggedInUser(String? userID) async {
    Database db = await database;
    await db.update('Metadata', {'loggedInUserID': userID});
  }

  Future<String?> getLoggedInUserID() async {
    Database db = await database;
    final List<Map<String, dynamic>> res = await db.query('Metadata');
    return res.isNotEmpty ? res.first['loggedInUserID'] as String? : null;
  }

  // --- LEADERBOARD LOGIK ---

  Future<List<Map<String, dynamic>>> getLeaderboardData({
    String? userID,
    int? volumeML,
    String? eventID,
    String sortBy = 'Schnellste zuerst',
  }) async {
    final db = await database;
    String query = '''
      SELECT s.*, u.username, (u.firstname || ' ' || u.lastname) as userRealName, e.name as eventName
      FROM Session s
      JOIN User u ON s.userID = u.userID
      LEFT JOIN Event e ON s.eventID = e.eventID
      WHERE s.localDeletedAt IS NULL
    ''';

    List<dynamic> args = [];
    if (userID != null && userID != 'Alle') {
      query += ' AND s.userID = ?';
      args.add(userID);
    }
    if (volumeML != null) {
      query += ' AND s.volumeML = ?';
      args.add(volumeML);
    }
    if (eventID != null && eventID != 'Alle') {
      query += ' AND s.eventID = ?';
      args.add(eventID);
    }

    if (sortBy == 'Schnellste zuerst') {
      query += ' ORDER BY s.durationMS ASC';
    } else if (sortBy == 'Langsamste zuerst') {
      query += ' ORDER BY s.durationMS DESC';
    } else {
      query += ' ORDER BY s.startedAt DESC';
    }

    return await db.rawQuery(query, args);
  }

  // Hilfsmethoden für Leaderboard-Aggregationen
  Future<List<Map<String, dynamic>>> getLeaderboardAverage() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT u.username, (u.firstname || ' ' || u.lastname) as userRealName,
      AVG(CAST(s.durationMS AS FLOAT) / (CAST(s.volumeML AS FLOAT) / 1000.0)) as avgValue
      FROM Session s
      JOIN User u ON s.userID = u.userID
      WHERE s.localDeletedAt IS NULL
      GROUP BY s.userID
      ORDER BY avgValue ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getLeaderboardCount() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT u.username, (u.firstname || ' ' || u.lastname) as userRealName,
      COUNT(s.sessionID) as avgValue
      FROM Session s
      JOIN User u ON s.userID = u.userID
      WHERE s.localDeletedAt IS NULL
      GROUP BY s.userID
      ORDER BY avgValue DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getLeaderboardTotalVolume() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT u.username, (u.firstname || ' ' || u.lastname) as userRealName,
      SUM(s.volumeML) as avgValue
      FROM Session s
      JOIN User u ON s.userID = u.userID
      WHERE s.localDeletedAt IS NULL
      GROUP BY s.userID
      ORDER BY avgValue DESC
    ''');
  }

  // --- DEBUG HILFE ---
  Future<void> debugPrintTable(String tableName) async {
    try {
      Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(tableName);
      print("DEBUG: [$tableName] - ${maps.length} Zeilen");
      for (var row in maps) print(row.toString());
    } catch (e) {
      print("Fehler beim Debug-Print: $e");
    }
  }

// --- Tims Sync Methoden ---

  Future<int> getCurrentDbSequence() async {
    final db = await database;

    final rows = await db.query(
      'Metadata',
      columns: ['dbSequence'],
      limit: 1,
    );

    if (rows.isEmpty) {
      await db.insert('Metadata', {'dbSequence': 0});
      return 0;
    }

    final value = rows.first['dbSequence'];

    if (value is int) return value;
    if (value is num) return value.toInt();

    return 0;
  }

  Future<int> setDbSequence(int newValue, {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;

    final rows = await db.query('Metadata', limit: 1);
    if (rows.isEmpty) {
      await db.insert('Metadata', {'dbSequence': newValue});
    } else {
      await db.update(
        'Metadata',
        {'dbSequence': newValue},
      );
    }

    return newValue;
  }

  Future<void> upsertUserFromServer(
      Map<String, dynamic> data, {
        DatabaseExecutor? executor,
      }) async {
    final db = executor ?? await database;

    final row = <String, dynamic>{
      'userID': data['id'],
      'firstname': data['first_name'],
      'lastname': data['last_name'],
      'username': data['username'],
      'eMail': data['email'],
      'bio': data['bio'],
      'localDeletedAt': null,
      'syncStatus': SyncStatus.synced.value,
    };

    await db.insert(
      'User',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertEventFromServer(Map<String, dynamic> data,
      {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;

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

  Future<void> upsertSessionFromServer(Map<String, dynamic> data,
      {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;

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
      'localDeletedAt': data['deleted_at'],
      'syncStatus': SyncStatus.synced.value,
    };

    await db.insert(
      'Session',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    final db = await database;
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

  Future<List<Map<String, dynamic>>> getPendingSessions() async {
    final db = await database;
    return db.query(
      'Session',
      where: 'syncStatus IN (?, ?, ?)',
      whereArgs: [
        SyncStatus.pendingCreate.value,
        SyncStatus.pendingUpdate.value,
        SyncStatus.pendingDelete.value
      ],
    );
  }

  Future<void> markEventSynced(String eventID) async {
    final db = await database;
    await db.update(
      'Event',
      {'syncStatus': SyncStatus.synced.value},
      where: 'eventID = ?',
      whereArgs: [eventID],
    );
  }

  Future<void> markSessionSynced(String sessionID) async {
    final db = await database;
    await db.update(
      'Session',
      {'syncStatus': SyncStatus.synced.value},
      where: 'sessionID = ?',
      whereArgs: [sessionID],
    );
  }

  Future<int> syncDeleteUserById(String userID,
      {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;
    return await db.delete(
      'User',
      where: 'userID = ?',
      whereArgs: [userID],
    );
  }

  Future<int> syncDeleteEventById(String eventID,
      {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;
    return await db.delete(
      'Event',
      where: 'eventID = ?',
      whereArgs: [eventID],
    );
  }

  Future<int> syncDeleteSessionById(String sessionID,
      {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;
    return await db.delete(
      'Session',
      where: 'sessionID = ?',
      whereArgs: [sessionID],
    );
  }

  Future<int> saveEventForSync(Map<String, dynamic> event) async {
    final db = await database;
    String eventID = event['eventID'] as String? ?? const Uuid().v4();

    final existingRows = await db.query(
      'Event',
      where: 'eventID = ?',
      whereArgs: [eventID],
      limit: 1,
    );

    final row = <String, dynamic>{
      'eventID': eventID,
      'name': event['name'],
      'description': event['description'],
      'dateFrom': event['dateFrom'],
      'dateTo': event['dateTo'],
      'latitude': event['latitude'],
      'longitude': event['longitude'],
      'localDeletedAt': null,
    };

    if (existingRows.isEmpty) {
      row['syncStatus'] = SyncStatus.pendingCreate.value;

      return await db.insert('Event', row);
    } else {
      final existing = existingRows.first;
      final currentStatus = existing['syncStatus'] as String?;
      final isStillLocalOnly = currentStatus == SyncStatus.pendingCreate.value;
      row['syncStatus'] = isStillLocalOnly
          ? SyncStatus.pendingCreate.value
          : SyncStatus.pendingUpdate.value;

      return await db.update(
        'Event',
        row,
        where: 'eventID = ?',
        whereArgs: [eventID],
      );
    }
  }

  Future<int> saveSessionForSync(Map<String, dynamic> session, {bool isEditing = false}) async {
    final db = await database;
    String sessionID = session['sessionID'] as String? ?? const Uuid().v4();

    final row = <String, dynamic>{
      'sessionID': sessionID,
      'volumeML': (session['volumeML'] as num?)?.toInt(),
      'name': session['name'],
      'description': session['description'],
      'latitude': (session['latitude'] as num?)?.toDouble(),
      'longitude': (session['longitude'] as num?)?.toDouble(),
      'startedAt': session['startedAt'],
      'userID': session['userID'],
      'eventID': session['eventID'],
      'durationMS': (session['durationMS'] as num?)?.toInt(),
      'valuesJSON': session['valuesJSON']?.toString(),
      'calibrationFactor': (session['calibrationFactor'] as num?)?.toInt(),
      'localDeletedAt': null,
    };

    if (!isEditing) {
      // Immer PENDING_CREATE, wenn es eine neue Session vom Trichter ist
      row['syncStatus'] = SyncStatus.pendingCreate.value;
      return await db.insert('Session', row, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      // Wenn wir im Bearbeitungsmodus sind, prüfen wir den bestehenden Status
      final existingRows = await db.query(
        'Session',
        where: 'sessionID = ?',
        whereArgs: [sessionID],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        // Sollte nicht passieren im Bearbeitungsmodus, aber als Fallback
        row['syncStatus'] = SyncStatus.pendingCreate.value;
        return await db.insert('Session', row);
      }

      final existing = existingRows.first;
      final currentStatus = existing['syncStatus'] as String?;

      // Wenn sie noch nie gesynct wurde, bleibt sie PENDING_CREATE
      if (currentStatus == SyncStatus.pendingCreate.value) {
        row['syncStatus'] = SyncStatus.pendingCreate.value;
      } else {
        // Ansonsten wird sie auf PENDING_UPDATE gesetzt
        row['syncStatus'] = SyncStatus.pendingUpdate.value;
      }

      return await db.update(
        'Session',
        row,
        where: 'sessionID = ?',
        whereArgs: [sessionID],
      );
    }
  }

  Future<void> markEventAsDeleted(String eventID) async {
    final db = await database;
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

  Future<void> markSessionAsDeleted(String sessionID) async {
    final db = await database;
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
}
