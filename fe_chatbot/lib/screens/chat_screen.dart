import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
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
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _loadSessionMessages();
    });
  }

  Future<void> _loadSessionMessages() async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (sessionProvider.currentSession != null) {
      setState(() => _isLoadingMessages = true);
      await chatProvider.loadMessages(sessionProvider.currentSession!.id);
      setState(() => _isLoadingMessages = false);
      _scrollToBottom(); // pindahkan ke sini agar scroll bekerja setelah pesan termuat
    }
  }

  Future<void> _checkPermissions() async {
    if (_permissionsChecked) return;

    final permissions = [
      await PermissionService.hasLocationPermission() ||
          await PermissionService.requestLocationPermission(),
      await PermissionService.hasMicrophonePermission() ||
          await PermissionService.requestMicrophonePermission(),
      await PermissionService.hasStoragePermission() ||
          await PermissionService.requestStoragePermission(),
    ];

    for (int i = 0; i < permissions.length; i++) {
      if (!permissions[i] && mounted) {
        final label = ['Lokasi', 'Mikrofon', 'Penyimpanan'][i];
        await PermissionService.showPermissionDialog(context, label);
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

  Future<void> _handleSubmitted(BuildContext context, String text) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);

    if (text.isEmpty && !chatProvider.hasImagePending) return;

    _textController.clear();
    final image = chatProvider.selectedImage;
    if (image != null) {
      final userImageMessage = ChatMessage(
        content: _textController.text,
        role: MessageRole.user,
        imageUrl: image.path,
      );
      // Tampilkan langsung ke UI (lokal)
      chatProvider.messages.add(userImageMessage);
      chatProvider.notifyListeners();
    }
    chatProvider.setLoading(true); 
    if (sessionProvider.currentSession != null) {
      await chatProvider.sendMessage(
          text, sessionProvider.currentSession!.id, sessionProvider);
          _scrollToBottom();
    }
    chatProvider.clearPendingImage(); 
    setState(() {});

    chatProvider.setLoading(false);
  }

  void _onSuggestionSelected(String suggestion) {
    _textController.text = suggestion;
  }

  Future<void> _openDeepSeekAI() async {
    const url = 'https://deepseek.ai';
    if (await canLaunch(url)) {
      await launch(url);
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
            size: 24,
            color: Colors.white,
          ),
          Switch(
            value: chatProvider.useVoiceOutput,
            onChanged: (value) => chatProvider.toggleVoiceOutput(),
            activeColor: Colors.white,
            activeTrackColor: Colors.green[300],
          ),
        ],
      ),
    );
  }

  void _showImageOptions() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.green),
            title: const Text('Ambil Foto'),
            onTap: () {
              Navigator.pop(context);
              chatProvider.pickImageFromCamera(context); // Open camera directly
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.green),
            title: const Text('Pilih dari Galeri'),
            onTap: () {
              Navigator.pop(context);
              chatProvider
                  .pickImageFromGallery(context); // Pick image from gallery
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: _isLoadingMessages
          ? const Scaffold(
              key: ValueKey('loading'),
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Memuat percakapan...",
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            )
          : _buildMainChatScreen(sessionProvider),
    );
  }
  Widget _buildMainChatScreen(SessionProvider sessionProvider) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.messages.isNotEmpty) {
          // _scrollToBottom();
        }

        return WillPopScope(
          onWillPop: () async {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SessionListScreen()),
            );
            return false;
          },
          child: Scaffold(
            backgroundColor: const Color.fromARGB(255, 247, 248, 242),
            appBar: AppBar(
              leading: IconButton(
              icon: const Icon(Icons.list, size: 28),
              onPressed: _showSessionList,
              tooltip: 'Riwayat Chat',
            ),
              title: Text(
                sessionProvider.currentSession?.name ?? 'PeTaniku',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 22, color: Colors.white),
              ),
              actions: [

                _buildVoiceOutputToggle(chatProvider),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  const WeatherWidget(),
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
                  onFinish: () async {
                    chatProvider.cancelListening();
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (sessionProvider.currentSession != null) {
                      await chatProvider.stopListening(
                        sessionProvider.currentSession!.id,
                        chatProvider.deviceId,
                      );
                    }
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                "🌾",
                style: TextStyle(fontSize: 60),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Selamat datang di PeTaniku!",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Tanyakan tentang teknik bertani, cuaca, atau hama tanaman",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 20,
                  ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildChatList(
    ChatProvider chatProvider, SessionProvider sessionProvider) {
  return ListView.builder(
    controller: _scrollController,
    padding: const EdgeInsets.all(16),
itemCount: chatProvider.messages.length +
  (chatProvider.isLoading ? 1 : 0),


    itemBuilder: (context, index) {


      // Cek apakah ini index untuk loading assistant
      if (index == chatProvider.messages.length && chatProvider.isLoading) {
        return ChatMessageItem(
          message: ChatMessage(
            content: "...",
            role: MessageRole.assistant,
          ),
          isTyping: true,
          contentBuilder: (text) => _buildBoldAndLinkifiedText(text),
        );
      }

      // Normal message
      final message = chatProvider.messages[index];

      final isAssistant = message.role == MessageRole.assistant;
      final isDeepSeek = isAssistant && message.content.contains("https://deepseek.ai");

      final messageWidget = ChatMessageItem(
        message: message,
        contentBuilder: (text) => _buildBoldAndLinkifiedText(text),
      );

      if (isDeepSeek) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Dismissible(
              key: Key(message.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white, size: 28),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Hapus Pesan', style: TextStyle(fontSize: 22)),
                      content: const Text('Apakah Anda yakin ingin menghapus pesan ini?', style: TextStyle(fontSize: 18)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Batal', style: TextStyle(fontSize: 18)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Hapus', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    );
                  },
                );
              },
              child: messageWidget,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 8),
              child: ElevatedButton(
                onPressed: _openDeepSeekAI,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text("Buka DeepSeek AI"),
              ),
            ),
          ],
        );
      }

      return messageWidget;
    },
  );
}

// Tambahkan ini di tempat kamu mem-build konten bot
Widget _buildBoldAndLinkifiedText(String text) {
  final RegExp boldExp = RegExp(r'\*(.*?)\*');
  final matches = boldExp.allMatches(text);
  final spans = <TextSpan>[];
  int currentIndex = 0;

  for (final match in matches) {
    if (match.start > currentIndex) {
      spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
    }

    final boldText = match.group(1) ?? '';
    spans.add(TextSpan(
      text: boldText,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    currentIndex = match.end;
  }

  if (currentIndex < text.length) {
    spans.add(TextSpan(text: text.substring(currentIndex)));
  }

  return Linkify(
    onOpen: (link) async {
      final uri = Uri.parse(link.url.trim().replaceAll(RegExp(r'[)\]]+$'), ''));
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Tidak bisa membuka: ${link.url}");
      }
    },
    text: text.replaceAll('*', ''), // agar Linkify tidak kacau karena simbol *
    style: const TextStyle(fontSize: 18, color: Colors.black),
    linkStyle: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
  );
}


Widget _buildInputArea(ChatProvider chatProvider, SessionProvider sessionProvider) {
  final bool hasText = _textController.text.isNotEmpty;
  final bool hasImage = chatProvider.hasImagePending;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chatProvider.selectedImage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      chatProvider.selectedImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                    onPressed: () {
                      chatProvider.clearPendingImage();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),

        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: chatProvider.isLoading || chatProvider.isListening
                    ? null
                    : _showImageOptions,
                icon: const Icon(Icons.attach_file, color: Colors.black, size: 28),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.green[200]!, width: 2),
                ),
                child: TextField(
                  controller: _textController,
                  style: TextStyle(
                    color: hasText ? Colors.black : Colors.grey[600],
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    hintText: hasImage
                        ? "Ketik pertanyaan untuk gambar ini..."
                        : "Tulis pertanyaan di sini...",
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 18),
                    border: InputBorder.none,
                    filled: false,
                  ),
                  enabled: !chatProvider.isListening && !chatProvider.isLoading,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (text) => _handleSubmitted(context, text),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF388E3C),
                radius: 24,
                child: IconButton(
                  onPressed: chatProvider.isLoading
                      ? null
                      : () {
                          if (hasText || hasImage) {
                            _handleSubmitted(context, _textController.text);
                          } else {
                            chatProvider.startListening(context);
                          }
                        },
                  icon: Icon(
                    hasText || hasImage
                        ? Icons.send
                        : (chatProvider.isListening ? Icons.mic_off : Icons.mic),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
        // const SizedBox(height: 12),
        // SuggestionChips(
        //   onSuggestionSelected: _onSuggestionSelected,
        //   chipTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 18),
        // ),
      ],
    ),
  );
}
}