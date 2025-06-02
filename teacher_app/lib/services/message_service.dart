import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a new message
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String senderType,
    required String recipientId,
    required String recipientName,
    required String recipientType,
    required String content,
  }) async {
    final message = {
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientType': recipientType,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'participants': [senderId, recipientId],
    };

    await _firestore.collection('messages').add(message);
  }

  // Get all conversations for a user
  Stream<QuerySnapshot> getConversations(String userId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get messages between two users
  Stream<QuerySnapshot> getMessages(String userId1, String userId2) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContainsAny: [userId1])
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    await _firestore
        .collection('messages')
        .doc(messageId)
        .update({'status': 'read'});
  }

  // Get unread message count
  Stream<QuerySnapshot> getUnreadMessageCount(String userId) {
    return _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .where('status', isEqualTo: 'sent')
        .snapshots();
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  // Get recent conversations
  Stream<List<Map<String, dynamic>>> getRecentConversations(String userId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          final conversations = <String, Map<String, dynamic>>{};
          
          for (var message in messages) {
            final otherUserId = message['senderId'] == userId 
                ? message['recipientId'] 
                : message['senderId'];
            
            if (!conversations.containsKey(otherUserId)) {
              conversations[otherUserId] = {
                'userId': otherUserId,
                'name': message['senderId'] == userId 
                    ? message['recipientName'] 
                    : message['senderName'],
                'lastMessage': message['content'],
                'timestamp': message['timestamp'],
                'unreadCount': message['status'] == 'sent' && 
                             message['recipientId'] == userId ? 1 : 0,
              };
            }
          }
          
          return conversations.values.toList()
            ..sort((a, b) => (b['timestamp'] as Timestamp?)?.compareTo(
                    a['timestamp'] as Timestamp? ?? Timestamp.now()) ??
                0);
        });
  }
} 