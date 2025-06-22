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

    final user = Provider.of<AppAuthProvider>(context, listen: false).currentUser;
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
    String otherUserId = participants.firstWhere((id) => id != authProvider.currentUser?.uid, orElse: () => '');
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() => _chatSearch = val.trim().toLowerCase()),
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
                      final otherUserId = chat.participants.firstWhere((id) => id != user.uid, orElse: () => '');
                      final otherUserName = chat.participantUsernames[otherUserId] ?? 'Unknown';
                      if (_chatSearch.isNotEmpty && !otherUserName.toLowerCase().contains(_chatSearch)) {
                        return Container();
                      }
                      return ListTile(
                        leading: CircleAvatar(child: Text(otherUserName.substring(0, 1).toUpperCase())),
                        title: Text(otherUserName),
                        subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: chat.lastMessageTime != null
                            ? Text(DateFormat.jm().format(chat.lastMessageTime))
                            : null,
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
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
