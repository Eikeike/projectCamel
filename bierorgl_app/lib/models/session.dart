import 'package:meta/meta.dart';

@immutable
class Session {
  final String id;
  final int volumeML;
  final String? name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final DateTime startedAt;
  final String userID;
  final String? eventID;
  final int durationMS;
  final String? valuesJSON;
  final int? calibrationFactor;

  // joins
  final String? username;
  final String? userRealName;
  final String? eventName;

  const Session({
    required this.id,
    required this.volumeML,
    this.name,
    this.description,
    this.latitude,
    this.longitude,
    required this.startedAt,
    required this.userID,
    this.eventID,
    required this.durationMS,
    this.valuesJSON,
    this.calibrationFactor,
    this.username,
    this.userRealName,
    this.eventName,
  });

  double get volumeLiters => volumeML / 1000.0;
  Duration get duration => Duration(milliseconds: durationMS);
  double? get avgFlowRateLPerS {
    if (durationMS <= 0 || volumeML <= 0) return null;
    return volumeLiters / (durationMS / 1000.0);
  }

  String get displayName => name?.isNotEmpty == true
      ? name!
      : eventName?.isNotEmpty == true
          ? eventName!
          : 'Session';

  static DateTime _parseRequiredDateTime(
    String? value,
    String fieldName,
  ) {
    if (value == null) {
      throw ArgumentError('$fieldName is null');
    }
    try {
      return DateTime.parse(value);
    } catch (_) {
      throw ArgumentError('Invalid $fieldName format: $value');
    }
  }

  static DateTime? _parseOptionalDateTime(String? value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  factory Session.fromSessionRow(Map<String, dynamic> row) {
    return Session(
      id: row['sessionID'] as String,
      volumeML: (row['volumeML'] as num?)?.toInt() ?? 0,
      name: row['name'] as String?,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startedAt: _parseRequiredDateTime(
        row['startedAt'] as String?,
        'startedAt',
      ),
      userID: row['userID'] as String,
      eventID: row['eventID'] as String?,
      durationMS: (row['durationMS'] as num?)?.toInt() ?? 0,
      valuesJSON: row['valuesJSON']?.toString(),
      calibrationFactor: (row['calibrationFactor'] as num?)?.toInt(),
    );
  }

  /// From `getHistory` query: `SELECT s.*, e.name as eventName`
  factory Session.fromHistoryRow(Map<String, dynamic> row) {
    return Session(
      id: row['sessionID'] as String,
      volumeML: (row['volumeML'] as num?)?.toInt() ?? 0,
      name: row['name'] as String?,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startedAt: _parseRequiredDateTime(
        row['startedAt'] as String?,
        'startedAt',
      ),
      userID: row['userID'] as String,
      eventID: row['eventID'] as String?,
      durationMS: (row['durationMS'] as num?)?.toInt() ?? 0,
      valuesJSON: row['valuesJSON']?.toString(),
      calibrationFactor: (row['calibrationFactor'] as num?)?.toInt(),
      eventName: row['eventName'] as String?,
    );
  }

  factory Session.fromLeaderboardRow(Map<String, dynamic> row) {
    return Session(
      id: row['sessionID'] as String,
      volumeML: (row['volumeML'] as num?)?.toInt() ?? 0,
      name: row['name'] as String?,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startedAt: _parseRequiredDateTime(
        row['startedAt'] as String?,
        'startedAt',
      ),
      userID: row['userID'] as String,
      eventID: row['eventID'] as String?,
      durationMS: (row['durationMS'] as num?)?.toInt() ?? 0,
      valuesJSON: row['valuesJSON']?.toString(),
      calibrationFactor: (row['calibrationFactor'] as num?)?.toInt(),
      username: row['username'] as String?,
      userRealName: row['userRealName'] as String?,
      eventName: row['eventName'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'sessionID': id,
      'volumeML': volumeML,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'startedAt': startedAt.toIso8601String(),
      'userID': userID,
      'eventID': eventID,
      'durationMS': durationMS,
      'valuesJSON': valuesJSON,
      'calibrationFactor': calibrationFactor,
    };
  }
}
