import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String content;
  final String? cleanContent; // Clean text without formatting for TTS
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
    id = id ?? const Uuid().v4(),
    timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      content: map['content'],
      cleanContent: map['clean_content'],
      role: _parseRole(map['role']),
      timestamp: map['timestamp'],
      imageUrl: map['image_path'],
      audioUrl: map['audio_path'],
      isAudio: map['audio_path'] != null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'cleanContent': cleanContent,
      'role': _roleToString(role),
      'timestamp': timestamp,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'isAudio': isAudio,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      cleanContent: json['cleanContent'],
      role: _parseRole(json['role']),
      timestamp: json['timestamp'],
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      isAudio: json['isAudio'] ?? false,
    );
  }
  
  static MessageRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.user;
    }
  }
  
  static String _roleToString(MessageRole role) {
    switch (role) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.system:
        return 'system';
    }
  }
  
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

