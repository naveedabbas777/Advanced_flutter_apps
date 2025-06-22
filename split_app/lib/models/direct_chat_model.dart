import 'package:cloud_firestore/cloud_firestore.dart';

class DirectChat {
  final String id;
  final List<String> participants;
  final Map<String, String> participantUsernames;
  final String lastMessage;
  final DateTime lastMessageTime;

  DirectChat({
    required this.id,
    required this.participants,
    required this.participantUsernames,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  factory DirectChat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectChat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantUsernames: Map<String, String>.from(data['participantUsernames'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
} 