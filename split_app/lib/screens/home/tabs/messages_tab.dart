import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_app/models/user_model.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/screens/direct_chat/direct_chat_screen.dart';
import 'package:split_app/screens/direct_chat/user_search_screen.dart';
import 'package:intl/intl.dart';
import 'package:split_app/models/direct_chat_model.dart';

class MessagesTab extends StatefulWidget {
  @override
  _MessagesTabState createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  String _chatSearch = '';
  List<DocumentSnapshot> _chats = [];
  bool _isLoadingChats = false;
  String? _chatsError;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    if (!mounted) return;
    setState(() {
      _isLoadingChats = true;
      _chatsError = null;
    });

    final user =
        Provider.of<AppAuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingChats = false;
        _chatsError = "User not logged in.";
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('direct_chats')
          .where('participants', arrayContains: user.uid)
          .orderBy('lastMessageTime', descending: true)
          .get();
      if (!mounted) return;
      setState(() {
        _chats = snapshot.docs;
        _isLoadingChats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chatsError = e.toString();
        _isLoadingChats = false;
      });
    }
  }

  Future<UserModel?> _getOtherUser(List<dynamic> participants) async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    String otherUserId = participants.firstWhere(
        (id) => id != authProvider.currentUser?.uid,
        orElse: () => '');
    if (otherUserId.isNotEmpty) {
      return await authProvider.getUserModel(otherUserId);
    }
    return null;
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
              : RefreshIndicator(
                  onRefresh: _fetchChats,
                  child: ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = DirectChat.fromFirestore(_chats[index]);
                      final otherUserId = chat.participants
                          .firstWhere((id) => id != user.uid, orElse: () => '');
                      final otherUserName =
                          chat.participantUsernames[otherUserId] ?? 'Unknown';
                      if (_chatSearch.isNotEmpty &&
                          !otherUserName.toLowerCase().contains(_chatSearch)) {
                        return Container();
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
                                    color: Colors.grey.shade300, width: 1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    child: Text(
                                      otherUserName
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
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
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                otherUserName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 17,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (chat.lastMessageTime != null)
                                              Text(
                                                DateFormat('hh:mm a').format(
                                                    chat.lastMessageTime),
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          chat.lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                  ),
                ),
        ),
      ],
    );
  }
}
