class GPSLocationData {
  final int id; // Backend expects Long; Dart int is 64-bit on 64-bit platforms.
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  GPSLocationData({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      };

  factory GPSLocationData.fromJson(Map<String, dynamic> json) {
    return GPSLocationData(
      id: json['id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
