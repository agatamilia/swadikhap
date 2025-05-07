class AudioMessage {
  final String id;
  final String filePath;
  final String transcription;
  final DateTime timestamp;
  final bool isUser;

  AudioMessage({
    required this.id,
    required this.filePath,
    required this.transcription,
    required this.timestamp,
    required this.isUser,
  });

  factory AudioMessage.fromJson(Map<String, dynamic> json) {
    return AudioMessage(
      id: json['id'],
      filePath: json['filePath'],
      transcription: json['transcription'],
      timestamp: DateTime.parse(json['timestamp']),
      isUser: json['isUser'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'transcription': transcription,
      'timestamp': timestamp.toIso8601String(),
      'isUser': isUser,
    };
  }
}
