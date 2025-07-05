import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../models/chat_session.dart';
import 'chat_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({Key? key}) : super(key: key);

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showCreateSessionDialog(BuildContext context) {
    _nameController.text = 'New Conversation';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create New Conversation',
          style: TextStyle(color: Colors.green[800]),
        ),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Conversation Name',
            labelStyle: TextStyle(color: Colors.green[700]),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green[600]!),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
              sessionProvider.createSession(_nameController.text).then((session) {
                // Navigate directly to ChatScreen with the newly created session
                Navigator.pop(context); // Close the dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(),
                  ),
                );
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameSessionDialog(BuildContext context, ChatSession session) {
    _nameController.text = session.name;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rename Conversation',
          style: TextStyle(color: Colors.green[800]),
        ),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'New Name',
            labelStyle: TextStyle(color: Colors.green[700]),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green[600]!),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
              sessionProvider.renameSession(session, _nameController.text).then((_) {
                Navigator.pop(context);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, ChatSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Conversation',
          style: TextStyle(color: Colors.green[800]),
        ),
        content: Text(
          'Are you sure you want to delete the conversation "${session.name}"? All messages will be permanently deleted.',
          style: TextStyle(color: Colors.green[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
              sessionProvider.deleteSession(session).then((_) {
                Navigator.pop(context);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Conversation History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<SessionProvider>(
        builder: (context, sessionProvider, child) {
          if (sessionProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
          }
          
          if (sessionProvider.sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _showCreateSessionDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Create New Conversation'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: sessionProvider.sessions.length,
            itemBuilder: (context, index) {
              final session = sessionProvider.sessions[index];
              final isCurrentSession = session.id == sessionProvider.currentSession?.id;
              
              return Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  _showDeleteConfirmationDialog(context, session);
                  return false;
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrentSession ? Colors.green[600] : Colors.green[100],
                    child: const Text('🌾', style: TextStyle(fontSize: 18)),
                  ),
                  title: Text(
                    session.name,
                    style: TextStyle(
                      fontWeight: isCurrentSession ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentSession ? Colors.green[800] : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(session.updatedAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.green[700]),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _showRenameSessionDialog(context, session);
                          break;
                        case 'delete':
                          _showDeleteConfirmationDialog(context, session);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    sessionProvider.setCurrentSession(session);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatScreen()),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSessionDialog(context),
        backgroundColor: Colors.green[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      // Using a common English format, you can adjust as needed (e.g., month/day/year)
      return '${date.day}/${date.month}/${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}