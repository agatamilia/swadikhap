enum MessageRole {
  user,
  assistant,
}

class ChatMessage {
  final String id;
  final String content;
  final String? cleanContent;
  final MessageRole role;
  final int timestamp;
  final String? imageUrl;
  final String? audioUrl;
  final bool isAudio;

  ChatMessage({
    String? id,
    required this.content,
    this.cleanContent,
    required this.role,
    int? timestamp,
    this.imageUrl,
    this.audioUrl,
    this.isAudio = false,
  }) : 
    this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    this.timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  // Factory constructor to create ChatMessage from a Map (e.g., from API response)
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: map['content'] ?? '',
      cleanContent: map['clean_content'],
      role: map['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      imageUrl: map['image_path'],
      audioUrl: map['audio_path'],
      isAudio: map['is_audio'] ?? false,
    );
  }

  // Factory constructor to create ChatMessage from JSON (e.g., from local storage or API)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? '',
      cleanContent: json['cleanContent'],
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      isAudio: json['isAudio'] ?? false,
    );
  }

  // Method to convert ChatMessage to a Map for API requests
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'clean_content': cleanContent,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'timestamp': timestamp,
      'image_path': imageUrl,
      'audio_path': audioUrl,
      'is_audio': isAudio,
    };
  }

  // Method to convert ChatMessage to JSON for local storage or JSON response handling
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'cleanContent': cleanContent,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'timestamp': timestamp,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'isAudio': isAudio,
    };
  }

  // Method to create API request map with sessionId included
  Map<String, dynamic> toApiMap(String sessionId) {
    return {
      'content': content,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'image_path': imageUrl,
      'audio_path': audioUrl,
      'device_id': '', // This will be filled by the API service
    };
  }

  // Helper method to create a copy of a ChatMessage with optional updates to fields
  ChatMessage copyWith({
    String? id,
    String? content,
    String? cleanContent,
    MessageRole? role,
    int? timestamp,
    String? imageUrl,
    String? audioUrl,
    bool? isAudio,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      cleanContent: cleanContent ?? this.cleanContent,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      isAudio: isAudio ?? this.isAudio,
    );
  }
}
