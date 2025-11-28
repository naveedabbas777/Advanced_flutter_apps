import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/badge_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupChatScreen(
      {Key? key, required this.groupId, required this.groupName})
      : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markChatAsSeen();
  }

  Future<void> _markChatAsSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('chatViews')
        .doc(user.uid)
        .set({'lastSeen': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
    // Update app icon badge
    await BadgeService().updateBadge();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Chat - ${widget.groupName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('group_messages')
                  .where('groupId', isEqualTo: widget.groupId)
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: \\${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                final userId = FirebaseAuth.instance.currentUser?.uid;
                return ListView.builder(
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == userId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['senderName'] ?? 'Unknown',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(msg['text'] ?? '',
                                style: TextStyle(fontSize: 16)),
                            if (msg['timestamp'] != null)
                              Text(
                                (msg['timestamp'] as Timestamp)
                                    .toDate()
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[500]),
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
                Expanded(
                  child: TextField(
                    controller: _messageController,
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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
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
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final username = userDoc.data()?['username'] ?? user.email ?? 'Unknown';
    await FirebaseFirestore.instance.collection('group_messages').add({
      'groupId': widget.groupId,
      'text': text,
      'senderId': user.uid,
      'senderName': username,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update the group with the last message info
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    // Note: Local notifications are handled automatically by NotificationListenerService
    // which filters out notifications for own messages and checks if user is viewing chat

    _messageController.clear();
    setState(() => _isSending = false);
  }
}
