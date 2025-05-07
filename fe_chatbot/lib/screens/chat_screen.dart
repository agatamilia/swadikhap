import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import '../providers/session_provider.dart';
import '../services/permission_service.dart';
import '../widgets/chat_message_item.dart';
import '../widgets/voice_input_overlay.dart';
import '../widgets/weather_widget.dart';
import '../widgets/suggestion_chips.dart';
import '../models/message.dart';
import 'session_list_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _loadSessionMessages();
    });
  }

  Future<void> _loadSessionMessages() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (sessionProvider.currentSession != null) {
      await chatProvider.loadMessages(sessionProvider.currentSession!.id);
    }
  }

  Future<void> _checkPermissions() async {
    if (_permissionsChecked) return;

    bool hasLocationPermission = await PermissionService.hasLocationPermission();
    if (!hasLocationPermission && mounted) {
      bool granted = await PermissionService.requestLocationPermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Lokasi');
      }
    }
    
    bool hasMicrophonePermission = await PermissionService.hasMicrophonePermission();
    if (!hasMicrophonePermission && mounted) {
      bool granted = await PermissionService.requestMicrophonePermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Mikrofon');
      }
    }
    
    bool hasStoragePermission = await PermissionService.hasStoragePermission();
    if (!hasStoragePermission && mounted) {
      bool granted = await PermissionService.requestStoragePermission();
      if (!granted && mounted) {
        await PermissionService.showPermissionDialog(context, 'Penyimpanan');
      }
    }
    
    _permissionsChecked = true;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(BuildContext context, String text) {
    if (text.isEmpty && !Provider.of<ChatProvider>(context, listen: false).hasImagePending) return;
    
    _textController.clear();
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    if (sessionProvider.currentSession != null) {
      // Using sendMessage that sends to API
      chatProvider.sendMessage(text, sessionProvider.currentSession!.id, sessionProvider);
    }
    
    _scrollToBottom();
  }

  void _onSuggestionSelected(String suggestion) {
    _textController.text = suggestion;
  }

  Future<void> _openDeepSeekAI() async {
    const url = 'https://deepseek.ai';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  void _showSessionList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SessionListScreen(),
      ),
    );
  }

  Widget _buildVoiceOutputToggle(ChatProvider chatProvider) {
    return Tooltip(
      message: "Aktifkan/nonaktifkan suara untuk jawaban asisten",
      child: Row(
        children: [
          Icon(
            chatProvider.useVoiceOutput ? Icons.volume_up : Icons.volume_off,
            size: 20,
            color: Colors.white,
          ),
          Switch(
            value: chatProvider.useVoiceOutput,
            onChanged: (value) {
              chatProvider.toggleVoiceOutput();
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.green[300]!,
            inactiveThumbColor: Colors.green[100]!,
            inactiveTrackColor: Colors.green[200]!,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.messages.isNotEmpty) {
          _scrollToBottom();
        }
        
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              sessionProvider.currentSession?.name ?? 'PeTaniku',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green[700],
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _showSessionList,
                tooltip: 'Riwayat Chat',
              ),
              _buildVoiceOutputToggle(chatProvider),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  WeatherWidget(
                    backgroundColor: Colors.green[600]!,
                    textColor: Colors.white,
                  ),
                  Expanded(
                    child: chatProvider.messages.isEmpty
                        ? _buildWelcomeScreen()
                        : _buildChatList(chatProvider, sessionProvider),
                  ),
                  _buildInputArea(chatProvider, sessionProvider),
                ],
              ),
              if (chatProvider.isListening) 
                VoiceInputOverlay(
                  onCancel: () => chatProvider.cancelListening(),
                  onFinish: () {
                    if (sessionProvider.currentSession != null) {
                      chatProvider.stopListening(sessionProvider.currentSession!.id, sessionProvider);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green[200],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                "🌾",
                style: TextStyle(fontSize: 60),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Welcome to PeTaniku!",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.green[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Tanyakan tentang teknik bertani, cuaca, atau hama tanaman",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.green[700],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _textController.text = "Hi, saya ingin bertanya";
              _handleSubmitted(context, _textController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              "Mulai Bertanya",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Asisten sedang mengetik",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        _buildLoadingDots(),
      ],
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(delay: 0),
        const SizedBox(width: 4),
        _buildDot(delay: 200),
        const SizedBox(width: 4),
        _buildDot(delay: 400),
      ],
    );
  }

  Widget _buildDot({required int delay}) {
    return AnimatedOpacity(
      opacity: 0.0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.green[600],
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildChatList(ChatProvider chatProvider, SessionProvider sessionProvider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatProvider.messages.length && chatProvider.isLoading) {
          return ChatMessageItem(
            message: ChatMessage(
              content: "...",
              role: MessageRole.assistant,
            ),
            isTyping: true,
            userColor: Colors.green[600]!,
            assistantColor: Colors.green[100]!,
            textColor: Colors.white,
          );
        }
        
        final message = chatProvider.messages[index];
        
        return Dismissible(
          key: Key(message.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: const Color(0xFFB71C1C),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(
                    'Hapus Pesan',
                    style: TextStyle(color: Colors.green[800]),
                  ),
                  content: Text(
                    'Apakah Anda yakin ingin menghapus pesan ini?',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Batal',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        'Hapus',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            if (sessionProvider.currentSession != null) {
              chatProvider.deleteMessage(message.id, sessionProvider.currentSession!.id);
            }
          },
          child: ChatMessageItem(
            message: message,
            userColor: message.role == MessageRole.user 
                ? Colors.green[600]! 
                : Colors.green[100]!,
            assistantColor: Colors.green[100]!,
            textColor: Colors.black87,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(ChatProvider chatProvider, SessionProvider sessionProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              FloatingActionButton(
                onPressed: chatProvider.isLoading 
                    ? null 
                    : chatProvider.isListening 
                        ? () => chatProvider.stopListening(sessionProvider.currentSession?.id ?? '', sessionProvider) 
                        : () => chatProvider.startListening(context),
                mini: true,
                backgroundColor: chatProvider.isListening 
                    ? Colors.green[800]
                    : Colors.green[600],
                child: Icon(
                  chatProvider.isListening ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              // Image picker button with camera icon
              FloatingActionButton(
                onPressed: chatProvider.isLoading 
                    ? null 
                    : () => chatProvider.pickImage(context),
                mini: true,
                backgroundColor: Colors.green[600],
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: chatProvider.hasImagePending 
                          ? "Ketik pertanyaan tentang gambar ini..."
                          : "Tanyakan sesuatu tentang pertanian...",
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                      suffixIcon: chatProvider.hasImagePending
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.green),
                              onPressed: chatProvider.clearPendingImage,
                            )
                          : null,
                    ),
                    style: TextStyle(color: Colors.green[800]),
                    enabled: !chatProvider.isListening && !chatProvider.isLoading,
                    onSubmitted: (text) => _handleSubmitted(context, text),
                  ),
                ),
              ),
              const SizedBox(width: 12),  
              
              FloatingActionButton(
                onPressed: chatProvider.isLoading 
                    ? null 
                    : () => _handleSubmitted(context, _textController.text),
                mini: true,
                backgroundColor: Colors.green[600],
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          SuggestionChips(
            onSuggestionSelected: _onSuggestionSelected,
            chipColor: Colors.green[100]!,
            textColor: Colors.green[800]!,
          ),
        ],
      ),
    );
  }
}
