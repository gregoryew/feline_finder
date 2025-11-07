import 'dart:math';

import 'package:flutter/material.dart';
import 'chatScreen.dart';

class ConversationListScreen extends StatelessWidget {
  const ConversationListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: ListView.builder(
        itemCount: 10, // Replace with actual number of conversations
        itemBuilder: (context, index) {
          return ConversationCard(
            senderName: 'Sender $index', // Replace with actual sender's name
            latestMessage:
                'This is the latest message from sender $index', // Replace with actual latest message
            isCurrentUserTurn: index % 2 ==
                0, // Replace with your logic to determine if it's the current user's turn
          );
        },
      ),
    );
  }
}

class ConversationCard extends StatelessWidget {
  final String senderName;
  final String latestMessage;
  final bool isCurrentUserTurn;
  final List<String> imageUrls = [
    'assets/Cartoon/Abyssinian.png',
    'assets/Cartoon/Balinese.png',
    'assets/Cartoon/Bombay.png',
    'assets/Cartoon/American_Curl.png',
    'assets/Cartoon/Devon_Rex.png',
    'assets/Cartoon/Abyssinian.png',
    'assets/Cartoon/Balinese.png',
    'assets/Cartoon/Bombay.png',
    'assets/Cartoon/American_Curl.png',
    'assets/Cartoon/Devon_Rex.png'
  ];

  ConversationCard({Key? key, 
    required this.senderName,
    required this.latestMessage,
    required this.isCurrentUserTurn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Random random = Random();
    final String randomImageUrl = imageUrls[random.nextInt(imageUrls.length)];

    return GestureDetector(
        onTap: () {
          // Navigate to the chat screen when tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                  currentUser: 'Adopter',
                  otherUser: senderName,
                  catName: 'Fluffy',
                  shelterName: 'Furry Homes' // Replace with cat name
                  ),
            ),
          );
        },
        child: Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60, // Adjust the width as needed
                  height: 60, // Adjust the height as needed
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                      child: Image.asset(randomImageUrl,
                          colorBlendMode: BlendMode.modulate,
                          height: 50,
                          width: 50)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrentUserTurn)
                  Container(
                    margin: const EdgeInsets.only(
                        left: 12), // Add margin around the "Your Turn" badge
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Your Turn',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ));
  }
}
