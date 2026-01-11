import 'package:meta/meta.dart';

@immutable
class Event {
  final String id;
  final String name;
  final String? description;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? latitude;
  final double? longitude;

  const Event({
    required this.id,
    required this.name,
    this.description,
    this.dateFrom,
    this.dateTo,
    this.latitude,
    this.longitude,
  });

  Event copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? latitude,
    double? longitude,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory Event.fromDb(Map<String, dynamic> map) {
    DateTime? parseDate(String? value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }

    return Event(
      id: map['eventID'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      dateFrom: parseDate(map['dateFrom'] as String?),
      dateTo: parseDate(map['dateTo'] as String?),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'eventID': id,
      'name': name,
      'description': description,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Event.fromServer(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return Event(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      description: json['description'] as String?,
      dateFrom: parseDate(json['date_from']),
      dateTo: parseDate(json['date_to']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class EventStats {
  final String eventId;
  final String eventName;
  final int sessionCount;
  final int totalVolumeML;

  const EventStats({
    required this.eventId,
    required this.eventName,
    required this.sessionCount,
    required this.totalVolumeML,
  });

  double get totalVolumeL => totalVolumeML / 1000.0;

  factory EventStats.fromRow(Map<String, dynamic> row) {
    return EventStats(
      eventId: row['eventID'] as String,
      eventName: row['name'] as String? ?? '',
      sessionCount: (row['count'] as num?)?.toInt() ?? 0,
      totalVolumeML: (row['totalVol'] as num?)?.toInt() ?? 0,
    );
  }
}
