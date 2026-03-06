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
      'map_snapshot_url': mapSnapshotUrl,
      'message_count': messageCount,
      'coordinates_json': coordinatesJson,
    };
  }
}
