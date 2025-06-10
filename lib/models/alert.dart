import 'package:latlong2/latlong.dart';

class Alert {
  final int? id;
  final String type;
  final double latitude;
  final double longitude;
  final DateTime reportedAt;
  final int confirmedCount;
  final bool isActive;
  final double? distance;
  final int? severity;
  final String? description;

  Alert({
    this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.reportedAt,
    this.confirmedCount = 1,
    this.isActive = true,
    this.distance,
    this.severity,
    this.description,
  });

  // Get LatLng object for map
  LatLng get location => LatLng(latitude, longitude);

  // Create Alert from JSON (from API)
  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      type: json['type'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      reportedAt: DateTime.parse(json['reported_at']),
      confirmedCount: json['confirmed_count'] ?? 1,
      isActive: json['is_active'] ?? true,
      distance: json['distance_meters']?.toDouble(),
      severity: json['severity'],
      description: json['description'] as String?,
    );
  }

  // Convert Alert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'reported_at': reportedAt.toIso8601String(),
      'confirmed_count': confirmedCount,
      'is_active': isActive,
      'severity': severity,
      'description': description,
    };
  }

  // Convert Alert to Map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'reported_at': reportedAt.toIso8601String(),
      'confirmed_count': confirmedCount,
      'is_active': isActive ? 1 : 0,
      'severity': severity,
      'description': description,
    };
  }

  // Create Alert from Map (from local storage)
  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'],
      type: map['type'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      reportedAt: DateTime.parse(map['reported_at']),
      confirmedCount: map['confirmed_count'] ?? 1,
      isActive: map['is_active'] == 1,
      severity: map['severity'],
      description: map['description'],
    );
  }

  // Get icon data based on alert type
  String get iconName {
    switch (type) {
      case 'accident':
        return 'car_crash';
      case 'fire':
        return 'local_fire_department';
      case 'police':
        return 'local_police';
      case 'blocked_road':
        return 'block';
      case 'traffic':
        return 'traffic';
      default:
        return 'warning';
    }
  }

  // Get color based on alert type
  int get color {
    switch (type) {
      case 'accident':
        return 0xFFFF0000; // Red
      case 'fire':
        return 0xFFFF6600; // Orange
      case 'police':
        return 0xFF0000FF; // Blue
      case 'blocked_road':
        return 0xFF000000; // Black
      case 'traffic':
        return 0xFFFFFF00; // Yellow
      default:
        return 0xFF888888; // Gray
    }
  }
}