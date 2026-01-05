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

  // werden in einigen queries schon gejoined, evtl kann man die hier zusammenholen
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
    if (durationMS == 0) return null;
    return volumeLiters / (durationMS / 1000.0);
  }

  String get displayName => name?.isNotEmpty == true
      ? name!
      : eventName?.isNotEmpty == true
          ? eventName!
          : 'Session';

  // no joins
  factory Session.fromSessionRow(Map<String, dynamic> row) {
    return Session(
      id: row['sessionID'] as String,
      volumeML: row['volumeML'] as int,
      name: row['name'] as String?,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startedAt: DateTime.parse(row['startedAt'] as String),
      userID: row['userID'] as String,
      eventID: row['eventID'] as String?,
      durationMS: row['durationMS'] as int,
      valuesJSON: row['valuesJSON']?.toString(),
      calibrationFactor: row['calibrationFactor'] as int?,
    );
  }

  // von getHistory session.* + eventName
  factory Session.fromHistoryRow(Map<String, dynamic> row) {
    return Session(
      id: row['sessionID'] as String,
      volumeML: row['volumeML'] as int,
      name: row['name'] as String?,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startedAt: DateTime.parse(row['startedAt'] as String),
      userID: row['userID'] as String,
      eventID: row['eventID'] as String?,
      durationMS: row['durationMS'] as int,
      valuesJSON: row['valuesJSON']?.toString(),
      calibrationFactor: row['calibrationFactor'] as int?,
      eventName: row['eventName'] as String?,
    );
  }

  /// From `getLeaderboardData` which joins User + Event
  factory Session.fromLeaderboardRow(Map<String, dynamic> row) {
    return Session(
      id: row['sessionID'] as String,
      volumeML: row['volumeML'] as int,
      name: row['name'] as String?,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startedAt: DateTime.parse(row['startedAt'] as String),
      userID: row['userID'] as String,
      eventID: row['eventID'] as String?,
      durationMS: row['durationMS'] as int,
      valuesJSON: row['valuesJSON']?.toString(),
      calibrationFactor: row['calibrationFactor'] as int?,
      username: row['username'] as String?,
      userRealName: row['userRealName'] as String?,
      eventName: row['eventName'] as String?,
    );
  }
}
