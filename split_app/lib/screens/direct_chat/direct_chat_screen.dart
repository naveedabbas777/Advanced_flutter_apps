import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:split_app/models/direct_message_model.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  const DirectChatScreen({Key? key, required this.chatId, required this.otherUserId, required this.otherUserName}) : super(key: key);

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  void _onTextChanged(String text) {
    if (!_isTyping) {
      _isTyping = true;
      _setTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _setTyping(false);
    });
  }

  Future<void> _setTyping(bool typing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('direct_chats')
        .doc(widget.chatId)
        .collection('typing')
        .doc(user.uid)
        .set({'typing': typing}, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _setTyping(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('direct_messages')
                  .where('chatId', isEqualTo: widget.chatId)
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: \\${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs.map((doc) => DirectMessage.fromFirestore(doc)).toList() ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                final userId = myUserId;
                return ListView.builder(
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == userId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.senderName,
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(msg.text, style: TextStyle(fontSize: 16)),
                            Text(
                              msg.timestamp.toLocal().toString().substring(0, 16),
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file),
                  tooltip: 'Send Image',
                  onPressed: () {
                    // Placeholder for the removed _sendImage method
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final username = userDoc.data()?['username'] ?? user.email ?? 'Unknown';
    await FirebaseFirestore.instance
        .collection('direct_messages')
        .add({
      'chatId': widget.chatId,
      'text': text,
      'senderId': user.uid,
      'senderName': username,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Update the chat with the last message info
    await FirebaseFirestore.instance
      .collection('direct_chats')
      .doc(widget.chatId)
      .update({
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': text,
      });
    _messageController.clear();
    setState(() => _isSending = false);
  }
} 