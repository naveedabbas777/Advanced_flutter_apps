import 'package:cloud_firestore/cloud_firestore.dart';

class DirectMessage {
  final String id;
  final String chatId;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime timestamp;

  DirectMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
  });

  factory DirectMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectMessage(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
} 