class AudioMessage {
  final String id;
  final String filePath;
  final String transcription;
  final DateTime createdAt;

  AudioMessage({
    required this.id,
    required this.filePath,
    required this.transcription,
    required this.createdAt,
  });
}