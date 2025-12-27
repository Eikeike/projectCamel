import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    String path = join(await getDatabasesPath(), 'my_app.db');
    return await openDatabase(
      path,
      version: 1,  // Erhöhe bei Schema-Änderungen und füge onUpgrade hinzu
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabelle User
    await db.execute('''
      CREATE TABLE User (
        userID TEXT PRIMARY KEY,
        name TEXT,
        surname TEXT,
        username TEXT,
        eMail TEXT,
        bio TEXT
      )
    ''');

    // Tabelle Event
    await db.execute('''
      CREATE TABLE Event (
        eventID TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        dateFrom TEXT,
        dateTo TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');

    // Tabelle Session
    await db.execute('''
      CREATE TABLE Session (
        sessionID TEXT PRIMARY KEY,
        startedAt TEXT,
        userID TEXT,
        volumeML INTEGER,
        durationMS INTEGER,
        eventID TEXT,
        name TEXT,
        description TEXT,
        latitude REAL,
        longitude REAL,
        FOREIGN KEY (userID) REFERENCES User (userID) ON DELETE CASCADE,
        FOREIGN KEY (eventID) REFERENCES Event (eventID) ON DELETE CASCADE
      )
    ''');
  }

  // CRUD für User
  Future<int> insertUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.insert('User', user);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    Database db = await database;
    return await db.query('User');
  }

  Future<int> updateUser(String userID, Map<String, dynamic> user) async {
    Database db = await database;
    return await db.update('User', user, where: 'userID = ?', whereArgs: [userID]);
  }

  Future<int> deleteUser(String userID) async {
    Database db = await database;
    return await db.delete('User', where: 'userID = ?', whereArgs: [userID]);
  }

  // CRUD für Event
  Future<int> insertEvent(Map<String, dynamic> event) async {
    Database db = await database;
    return await db.insert('Event', event);
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    Database db = await database;
    return await db.query('Event');
  }

  Future<int> updateEvent(String eventID, Map<String, dynamic> event) async {
    Database db = await database;
    return await db.update('Event', event, where: 'eventID = ?', whereArgs: [eventID]);
  }

  Future<int> deleteEvent(String eventID) async {
    Database db = await database;
    return await db.delete('Event', where: 'eventID = ?', whereArgs: [eventID]);
  }

  // CRUD für Session
  Future<int> insertSession(Map<String, dynamic> session) async {
    Database db = await database;
    return await db.insert('Session', session);
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    Database db = await database;
    return await db.query('Session');
  }

  Future<List<Map<String, dynamic>>> getSessionsForUser(String userID) async {
    Database db = await database;
    return await db.query('Session', where: 'userID = ?', whereArgs: [userID]);
  }

  Future<List<Map<String, dynamic>>> getSessionsForEvent(String eventID) async {
    Database db = await database;
    return await db.query('Session', where: 'eventID = ?', whereArgs: [eventID]);
  }

  Future<int> updateSession(String sessionID, Map<String, dynamic> session) async {
    Database db = await database;
    return await db.update('Session', session, where: 'sessionID = ?', whereArgs: [sessionID]);
  }

  Future<int> deleteSession(String sessionID) async {
    Database db = await database;
    return await db.delete('Session', where: 'sessionID = ?', whereArgs: [sessionID]);
  }
}