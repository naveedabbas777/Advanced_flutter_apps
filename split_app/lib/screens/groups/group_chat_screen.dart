import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupChatScreen({Key? key, required this.groupId, required this.groupName}) : super(key: key);

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
        .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
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
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': user.uid,
      'senderName': username,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
    setState(() => _isSending = false);
    // Send notification to group members
    await _sendChatNotificationToGroup(text, username, user.uid);
  }

  Future<void> _sendChatNotificationToGroup(String message, String senderName, String senderId) async {
    // Fetch group members
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
    final members = groupDoc.data()?['members'] as List<dynamic>?;
    if (members == null) return;
    List<String> userIds = [];
    for (var m in members) {
      if (m is Map && m['userId'] != null && m['userId'] != senderId) {
        userIds.add(m['userId']);
      }
    }
    // Fetch FCM tokens
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: userIds).get();
    List<String> tokens = [];
    for (var doc in usersSnapshot.docs) {
      final token = doc.data()['fcmToken'];
      if (token != null && token is String) tokens.add(token);
    }
    // Send notification to each token
    for (final token in tokens) {
      await _sendFcmNotification(
        token,
        title: '${widget.groupName} - New Message',
        body: '$senderName: $message',
      );
    }
  }

  Future<void> _sendFcmNotification(String token, {required String title, required String body}) async {
    const String serverKey = 'YOUR_SERVER_KEY_HERE'; // <-- Replace with your FCM server key
    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    };
    final payload = {
      'to': token,
      'notification': {
        'title': title,
        'body': body,
      },
      'data': {
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    };
    try {
      final response = await http.post(url, headers: headers, body: jsonEncode(payload));
      if (response.statusCode != 200) {
        print('FCM send error: ${response.body}');
      }
    } catch (e) {
      print('FCM send exception: $e');
    }
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
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
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
                              msg['senderName'] ?? 'Unknown',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(msg['text'] ?? '', style: TextStyle(fontSize: 16)),
                            if (msg['timestamp'] != null)
                              Text(
                                (msg['timestamp'] as Timestamp).toDate().toLocal().toString().substring(0, 16),
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
} 