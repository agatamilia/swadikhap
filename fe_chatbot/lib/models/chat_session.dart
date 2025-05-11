class ChatSession {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final String deviceId;
  
  ChatSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
  });
  
  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      name: map['name'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      deviceId: map['device_id'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'device_id': deviceId,
    };
  }
  
  ChatSession copyWith({
    String? id,
    String? name,
    int? createdAt,
    int? updatedAt,
    String? deviceId,
  }) {
    return ChatSession(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}