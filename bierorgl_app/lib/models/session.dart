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

  factory Session.fromServer(Map<String, dynamic> json) {
    DateTime parseStartedAt(dynamic v) {
      if (v == null) {
        throw ArgumentError('started_at is null');
      }
      if (v is String) {
        return _parseRequiredDateTime(v, 'started_at');
      }
      throw ArgumentError('Invalid started_at type: ${v.runtimeType}');
    }

    return Session(
      id: (json['id'] ?? '') as String,
      volumeML: (json['volume'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      startedAt: parseStartedAt(json['started_at']),
      userID: (json['user'] ?? '') as String,
      eventID: json['event'] as String?,
      durationMS: (json['duration_ms'] as num?)?.toInt() ?? 0,
      valuesJSON: json['values']
          ?.toString(), // adjust if values is already a JSON string
      calibrationFactor: (json['calibration_factor'] as num?)?.toInt(),
    );
  }
}

@immutable
class AggregatedLeaderboardEntry {
  final String userId;
  final String? username;
  final num value;
  final int? rank;

  const AggregatedLeaderboardEntry({
    required this.userId,
    required this.value,
    this.username,
    this.rank,
  });

  factory AggregatedLeaderboardEntry.fromDb(
    Map<String, dynamic> row, {
    String userIdKey = 'userID',
    String valueKey = 'value',
    String usernameKey = 'username',
    String rankKey = 'rank',
  }) {
    return AggregatedLeaderboardEntry(
      userId: (row[userIdKey] ?? '').toString(),
      username: row[usernameKey] as String?,
      value: (row[valueKey] as num?) ?? 0,
      rank: (row[rankKey] as num?)?.toInt(),
    );
  }

  /// Create a copy with a new rank value
  AggregatedLeaderboardEntry copyWithRank(int newRank) {
    return AggregatedLeaderboardEntry(
      userId: userId,
      username: username,
      value: value,
      rank: newRank,
    );
  }
}
