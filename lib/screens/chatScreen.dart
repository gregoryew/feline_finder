import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  final String currentUser;
  final String otherUser;
  final String catName;
  final String shelterName;

  const ChatScreen(
      {Key? key, required this.currentUser,
      required this.otherUser,
      required this.catName,
      required this.shelterName}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // List to store messages

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(String text, bool isCurrentUser) {
    setState(() {
      _messages.add({
        'text': text,
        'isCurrentUser': isCurrentUser,
      });
      _messageController.clear();
    });
  }

  Widget _buildMessageItem(BuildContext context, int index) {
    // Get message details
    final message = _messages[index];
    final dynamic timestamp =
        message['timestamp']; // Replace with your message timestamp
    DateTime messageDate = DateTime.now();
    bool isFirstMessage = true;
    if (_messages.isNotEmpty && timestamp is DateTime) {
      messageDate = message['timestamp']; // Replace with your message timestamp
      isFirstMessage = index == 0 ||
          messageDate.day !=
              (_messages[index - 1]['timestamp'] as DateTime?)?.day;
    }

    return Column(
      children: [
        if (isFirstMessage)
          Center(
            child: Text(
              DateFormat('MMM d yyyy')
                  .format(messageDate), // Format this date as "MMM D YYYY"
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        MessageBubble(
          message: message['text'],
          isCurrentUser: message['isCurrentUser'],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/Cartoon/Devon_Rex.png'),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "⚪ ${widget.otherUser}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.catName} - ${widget.shelterName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: _buildMessageItem, // Use the custom builder
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.photo),
                onPressed: () {
                  // Handle photo sending
                },
              ),
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () {
                  // Handle file attaching
                },
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextField(
                            controller: _messageController,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration.collapsed(
                              hintText: 'Type a message...',
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          final messageText = _messageController.text;
                          if (messageText.isNotEmpty) {
                            _sendMessage(messageText, true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;

  const MessageBubble({Key? key, required this.message, required this.isCurrentUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue : Colors.grey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: AppTheme.offWhite,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
