import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderType; // 'teacher' or 'student'
  final String recipientId;
  final String recipientName;
  final String recipientType; // 'teacher' or 'student'
  final String content;
  final DateTime timestamp;
  final String status; // 'sent', 'delivered', 'read'

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.recipientId,
    required this.recipientName,
    required this.recipientType,
    required this.content,
    required this.timestamp,
    required this.status,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderType: data['senderType'] ?? '',
      recipientId: data['recipientId'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientType: data['recipientType'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      status: data['status'] ?? 'sent',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientType': recipientType,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }
} 