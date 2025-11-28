import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/screens/direct_chat/direct_chat_screen.dart';
import 'package:intl/intl.dart';
import 'package:split_app/models/direct_chat_model.dart';
import 'package:badges/badges.dart' as badges;

class MessagesTab extends StatefulWidget {
  @override
  _MessagesTabState createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  String _chatSearch = '';

  Future<int> _getUnreadCount(String chatId, String userId) async {
    // Get last seen for direct chat
    final chatViewDoc = await FirebaseFirestore.instance
        .collection('direct_chats')
        .doc(chatId)
        .collection('chatViews')
        .doc(userId)
        .get();

    Timestamp? lastSeen;
    if (chatViewDoc.exists) {
      lastSeen = chatViewDoc.data()?['lastSeen'] as Timestamp?;
    }

    final messagesQuery = await FirebaseFirestore.instance
        .collection('direct_messages')
        .where('chatId', isEqualTo: chatId)
        .get();

    if (lastSeen != null) {
      return messagesQuery.docs.where((doc) {
        final ts = doc.data()['timestamp'] as Timestamp?;
        final senderId = doc.data()['senderId'] as String?;
        return ts != null &&
            ts.toDate().isAfter(lastSeen!.toDate()) &&
            senderId != userId;
      }).length;
    } else {
      return messagesQuery.docs
          .where((doc) => doc.data()['senderId'] != userId)
          .length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppAuthProvider>(context).currentUser;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) =>
                setState(() => _chatSearch = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: user == null
              ? const Center(child: Text('User not logged in.'))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('direct_chats')
                      .where('participants', arrayContains: user.uid)
                      .orderBy('lastMessageTime', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final chats = snapshot.data?.docs ?? [];
                    return RefreshIndicator(
                      onRefresh: () async {
                        // Refresh is handled by StreamBuilder automatically
                      },
                      child: ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = DirectChat.fromFirestore(chats[index]);
                          final otherUserId = chat.participants.firstWhere(
                              (id) => id != user.uid,
                              orElse: () => '');
                          final otherUserName =
                              chat.participantUsernames[otherUserId] ??
                                  'Unknown';
                          if (_chatSearch.isNotEmpty &&
                              !otherUserName
                                  .toLowerCase()
                                  .contains(_chatSearch)) {
                            return Container();
                          }
                          return FutureBuilder<int>(
                            future: _getUnreadCount(chat.id, user.uid),
                            builder: (context, unreadSnapshot) {
                              int unreadCount = 0;
                              if (unreadSnapshot.hasData) {
                                unreadCount = unreadSnapshot.data!;
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 6.0),
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  elevation: 1,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DirectChatScreen(
                                            chatId: chat.id,
                                            otherUserId: otherUserId,
                                            otherUserName: otherUserName,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      child: Row(
                                        children: [
                                          badges.Badge(
                                            showBadge: unreadCount > 0,
                                            badgeContent: Text(
                                              unreadCount > 99
                                                  ? '99+'
                                                  : unreadCount.toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10),
                                            ),
                                            position:
                                                badges.BadgePosition.topEnd(
                                                    top: -8, end: -8),
                                            child: CircleAvatar(
                                              radius: 26,
                                              child: Text(
                                                otherUserName
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        otherUserName,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 17,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormat('hh:mm a')
                                                          .format(chat
                                                              .lastMessageTime),
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  chat.lastMessage,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
