enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final String? imageUrl; // For storing image paths
  final bool isAudio; // New field for audio messages

  ChatMessage({
    required this.content,
    required this.role,
    String? id,
    DateTime? timestamp,
    this.imageUrl,
    this.isAudio = false, // Default to false for text messages
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: map['content'],
      role: map['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: DateTime.parse(map['timestamp']),
      imageUrl: map['image_url'],
      isAudio: map['is_audio'] ?? false, // Handle potential null value
    );
  }

  Map<String, dynamic> toApiMap(String sessionId) {
    return {
      'id': id,
      'session_id': sessionId,
      'content': content,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'timestamp': timestamp.toIso8601String(),
      if (imageUrl != null) 'image_url': imageUrl,
      'is_audio': isAudio, // Include audio flag in API payload
    };
  }

  // Added copyWith method
  ChatMessage copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    String? imageUrl,
    bool? isAudio,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      isAudio: isAudio ?? this.isAudio,
    );
  }
}