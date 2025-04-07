class ChatSession {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  
  ChatSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      name: map['name'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
  
  ChatSession copyWith({
    String? id,
    String? name,
    int? createdAt,
    int? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


// class ChatSession {
//   final String id;
//   final String name;
//   final int createdAt;
//   final int updatedAt;
  
//   ChatSession({
//     required this.id,
//     required this.name,
//     required this.createdAt,
//     required this.updatedAt,
//   });
  
//   factory ChatSession.fromMap(Map<String, dynamic> map) {
//   return ChatSession(
//     id: map['id'],
//     name: map['name'],
//     createdAt: map['created_at'] is int ? map['created_at'] : DateTime.parse(map['created_at'].toString()).millisecondsSinceEpoch,
//     updatedAt: map['updated_at'] is int ? map['updated_at'] : DateTime.parse(map['updated_at'].toString()).millisecondsSinceEpoch,
//   );
// }

// // Add helper methods for DateTime conversion
// DateTime get createdAtDateTime => DateTime.fromMillisecondsSinceEpoch(createdAt);
// DateTime get updatedAtDateTime => DateTime.fromMillisecondsSinceEpoch(updatedAt);

// // Format date for display
// String get formattedDate {
//   final date = updatedAtDateTime;
//   return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
// }
  
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'created_at': createdAt,
//       'updated_at': updatedAt,
//     };
//   }
  
//   ChatSession copyWith({
//     String? id,
//     String? name,
//     int? createdAt,
//     int? updatedAt,
//   }) {
//     return ChatSession(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       createdAt: createdAt ?? this.createdAt,
//       updatedAt: updatedAt ?? this.updatedAt,
//     );
//   }
// }

