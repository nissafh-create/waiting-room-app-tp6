import 'sync_status.dart';

class Client {
  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final double? locationAccuracy;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  const Client({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.locationAccuracy,
    required this.createdAt,
    this.syncStatus = SyncStatus.synced,
  });

  bool get hasLocation => lat != null && lng != null;

  String get locationText {
    if (!hasLocation) {
      return 'Location not captured';
    }
    return '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}';
  }

  /// Serialization for Supabase (Business data only)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'location_accuracy_m': locationAccuracy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Serialization for SQLite (Includes local synchronization status)
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'location_accuracy_m': locationAccuracy,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Client.fromSupabaseMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'].toString(),
      name: map['name'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      locationAccuracy: (map['location_accuracy_m'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: SyncStatus.synced,
    );
  }

  factory Client.fromLocalMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'].toString(),
      name: map['name'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      locationAccuracy: (map['location_accuracy_m'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (status) => status.name == map['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }

  // Backward-compatibility helpers
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'name':
        return name;
      case 'lat':
        return lat;
      case 'lng':
        return lng;
      case 'location_accuracy_m':
        return locationAccuracy;
      case 'created_at':
        return createdAt.toIso8601String();
      case 'sync_status':
        return syncStatus.name;
      case 'is_synced':
        return syncStatus == SyncStatus.synced ? 1 : 0;
      default:
        return null;
    }
  }

  factory Client.fromMap(Map<String, dynamic> map) => Client.fromLocalMap(map);
  Map<String, dynamic> toMap() => toLocalMap();

  @override
  String toString() => 'Client(id: $id, name: $name, lat: $lat, lng: $lng, syncStatus: $syncStatus)';
}
