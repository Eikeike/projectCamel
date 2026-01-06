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
}
