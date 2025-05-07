import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/message.dart';

class ChatMessageItem extends StatelessWidget {
  final ChatMessage message;
  final bool isTyping;
  final Color userColor;
  final Color assistantColor;
  final Color textColor;

  const ChatMessageItem({
    Key? key,
    required this.message,
    this.isTyping = false,
    required this.userColor,
    required this.assistantColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: isUser ? Colors.green[600] : Colors.white, // User: green, Bot: white
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isUser 
                            ? Colors.green[600]!.withOpacity(0.2)
                            : Colors.green[100]!,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isUser ? "👨‍🌾" : "🤖",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Message content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isTyping)
                            _buildTypingIndicator()
                          else
                            _buildMessageContent(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    final isUser = message.role == MessageRole.user;
    
    if (message.imageUrl != null) {
      // Check if image is from local file or server URL
      final isLocalFile = message.imageUrl!.startsWith('/') && 
                          !message.imageUrl!.startsWith('/uploads');
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isLocalFile
                ? Image.file(
                    File(message.imageUrl!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  )
                : Image.network(
                    '${ApiConfig.baseUrl}${message.imageUrl!}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print("Error loading image: $error");
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(height: 8),
                              Text('Gagal memuat gambar: ${error.toString().substring(0, min(error.toString().length, 50))}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          if (message.content.isNotEmpty)
            if (!isUser) 
              RichText(
                text: TextSpan(
                  style: TextStyle(color: isUser ? Colors.white : Colors.black), // User: white text, Bot: black text
                  children: _parseMarkdownText(message.content),
                ),
              )
            else
              Text(
                message.content,
                style: const TextStyle(color: Colors.white), // User: white text
              ),
        ],
      );
    }
      
    if (!isUser) {
      return RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black), // Bot: black text
          children: _parseBoldText(message.content),
        ),
      );
    }
    
    return Text(
      message.content,
      style: const TextStyle(color: Colors.white), // User: white text
    );
  }

  List<TextSpan> _parseMarkdownText(String text) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');
    bool inList = false;

    for (final line in lines) {
      if (line.startsWith('- ')) {
        // List item
        if (!inList) {
          spans.add(const TextSpan(text: '\n'));
          inList = true;
        }
        spans.addAll([
          const TextSpan(text: '• ', style: TextStyle(fontSize: 16)),
          TextSpan(text: line.substring(2) + '\n'),
        ]);
      } else if (line.startsWith('**')) {
        // Bold text
        final parts = line.split('**');
        for (int i = 0; i < parts.length; i++) {
          if (i % 2 == 1) {
            spans.add(TextSpan(
              text: parts[i],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ));
          } else if (parts[i].isNotEmpty) {
            spans.add(TextSpan(text: parts[i]));
          }
        }
        spans.add(const TextSpan(text: '\n'));
        inList = false;
      } else {
        // Regular text
        spans.add(TextSpan(text: line + '\n'));
        inList = false;
      }
    }

    return spans;
  }

  List<TextSpan> _parseBoldText(String text) {
    final List<TextSpan> spans = [];
    final parts = text.split('*');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black, // Bot: black text
            ),
          ),
        );
      } else if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(color: Colors.black), // Bot: black text
        ));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black), // Bot: black text
      ));
    }

    return spans;
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green[400],
              shape: BoxShape.circle,
            ),
            child: const _PulsingDot(),
          ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(),
    );
  }
}
