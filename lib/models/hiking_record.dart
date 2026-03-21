class HikingRecord {
  final String id;
  final int userId;
  final DateTime startTime;
  final DateTime endTime;
  final int duration; // seconds
  final double distance; // km
  final int calories; // kcal
  final int elevationGain; // m
  final String? startLocation;
  final String? endLocation;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final String? mapSnapshotUrl;
  final int messageCount;
  
  // Extra fields for detail view
  final String? coordinatesJson; // JSON string of coordinates
  
  HikingRecord({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distance,
    required this.calories,
    required this.elevationGain,
    this.startLocation,
    this.endLocation,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.mapSnapshotUrl,
    this.messageCount = 0,
    this.coordinatesJson,
  });

  factory HikingRecord.fromJson(Map<String, dynamic> json) {
    return HikingRecord(
      id: json['id'].toString(),
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString()) ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['start_time'] * 1000),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['end_time'] * 1000),
      duration: json['duration'],
      distance: (json['distance'] as num).toDouble(),
      calories: json['calories'],
      elevationGain: json['elevation_gain'],
      startLocation: json['start_location'],
      endLocation: json['end_location'],
      startLatitude: json['start_latitude'] != null ? (json['start_latitude'] as num).toDouble() : null,
      startLongitude: json['start_longitude'] != null ? (json['start_longitude'] as num).toDouble() : null,
      endLatitude: json['end_latitude'] != null ? (json['end_latitude'] as num).toDouble() : null,
      endLongitude: json['end_longitude'] != null ? (json['end_longitude'] as num).toDouble() : null,
      mapSnapshotUrl: json['map_snapshot_url'],
      messageCount: json['message_count'] ?? 0,
      coordinatesJson: json['coordinates_json'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.millisecondsSinceEpoch ~/ 1000,
      'end_time': endTime.millisecondsSinceEpoch ~/ 1000,
      'duration': duration,
      'distance': distance,
      'calories': calories,
      'elevation_gain': elevationGain,
      'start_location': startLocation,
      'end_location': endLocation,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'map_snapshot_url': mapSnapshotUrl,
      'message_count': messageCount,
      'coordinates_json': coordinatesJson,
    };
  }

  HikingRecord copyWith({
    String? id,
    int? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    double? distance,
    int? calories,
    int? elevationGain,
    String? startLocation,
    String? endLocation,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    String? mapSnapshotUrl,
    int? messageCount,
    String? coordinatesJson,
  }) {
    return HikingRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
      elevationGain: elevationGain ?? this.elevationGain,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      mapSnapshotUrl: mapSnapshotUrl ?? this.mapSnapshotUrl,
      messageCount: messageCount ?? this.messageCount,
      coordinatesJson: coordinatesJson ?? this.coordinatesJson,
    );
  }
}
