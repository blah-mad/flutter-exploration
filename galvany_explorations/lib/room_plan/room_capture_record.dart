class RoomCaptureRecord {
  const RoomCaptureRecord({
    required this.id,
    required this.displayName,
    required this.createdAt,
    this.usdzPath,
    this.jsonPath,
  });

  final String id;
  final String displayName;
  final DateTime createdAt;
  final String? usdzPath;
  final String? jsonPath;

  bool get hasUsdz => usdzPath != null && usdzPath!.isNotEmpty;

  bool get hasJson => jsonPath != null && jsonPath!.isNotEmpty;

  RoomCaptureRecord copyWith({
    String? displayName,
    DateTime? createdAt,
    String? usdzPath,
    String? jsonPath,
  }) {
    return RoomCaptureRecord(
      id: id,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      usdzPath: usdzPath ?? this.usdzPath,
      jsonPath: jsonPath ?? this.jsonPath,
    );
  }

  factory RoomCaptureRecord.fromJson(Map<String, dynamic> json) {
    return RoomCaptureRecord(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Room Capture',
      createdAt: DateTime.parse(json['createdAt'] as String),
      usdzPath: json['usdzPath'] as String?,
      jsonPath: json['jsonPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'usdzPath': usdzPath,
      'jsonPath': jsonPath,
    };
  }
}
