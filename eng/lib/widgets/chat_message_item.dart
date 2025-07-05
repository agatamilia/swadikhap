import 'dart:io';
import 'package:flutter/material.dart';
import '../models/message.dart';

class ChatMessageItem extends StatelessWidget {
  final ChatMessage message;
  final bool isTyping;
  final Widget Function(String)? contentBuilder;

  const ChatMessageItem({
    Key? key,
    required this.message,
    this.isTyping = false,
    this.contentBuilder,
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
          color: isUser 
              ? Theme.of(context).colorScheme.primary 
              : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 8),
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
                            ? Theme.of(context).colorScheme.primaryContainer 
                            : Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isUser ? "👨‍🌾" : "🤖",
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Message content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isTyping
                              ? _buildTypingIndicator()
                              : _buildMessageContent(context),
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
  
  Widget _buildMessageContent(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    if (message.imageUrl != null) {
      final isNetworkImage = message.imageUrl!.startsWith('http');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isNetworkImage
                ? Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: MediaQuery.of(context).size.width * 0.4,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('Failed to load image from server.');
                    },
                  )
                : Image.file(
                    File(message.imageUrl!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
          const SizedBox(height: 8),
          if (!isUser && contentBuilder != null)
            contentBuilder!(message.content)
          else
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
                fontSize: 18,
              ),
            ),
        ],
      );
    }

    if (!isUser && contentBuilder != null) {
      return DefaultTextStyle(
        style: const TextStyle(fontSize: 18, color: Colors.black),
        child: contentBuilder!(message.content),
      );
    }

    return Text(
      message.content,
      style: TextStyle(color: isUser ? Colors.white : Colors.black, fontSize: 18),
    );
  }

  List<TextSpan> _parseBoldText(String text) {
    final List<TextSpan> spans = [];
    final parts = text.split('*');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) { // Part with *...* (odd index)
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18,),
          ),
        );
      } else if (parts[i].isNotEmpty) { // Normal part
        spans.add(TextSpan(text: parts[i]));
      }
    }

    // If there are no asterisks, return plain text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
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
              color: Colors.green[300],
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

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
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