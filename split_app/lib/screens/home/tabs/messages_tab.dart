import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_app/models/user_model.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/screens/direct_chat/direct_chat_screen.dart';
import 'package:split_app/screens/direct_chat/user_search_screen.dart';
import 'package:intl/intl.dart';

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
          child: _isLoadingChats
              ? const Center(child: CircularProgressIndicator())
              : _chatsError != null
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error loading chats: $_chatsError', textAlign: TextAlign.center),
                    ))
                  : _chats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No direct messages yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: Icon(Icons.refresh),
                                label: Text('Reload'),
                                onPressed: _fetchChats,
                              ),
                              SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: Icon(Icons.message),
                                label: Text('Start a New Chat'),
                                onPressed: () {
                                  final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
                                  final currentUserId = authProvider.currentUser?.uid;
                                  if (currentUserId != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => UserSearchScreen(currentUserId: currentUserId)),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Cannot start a new chat. User not logged in."))
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchChats,
                          child: ListView.builder(
                            itemCount: _chats.length,
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              final data = chat.data() as Map<String, dynamic>;
                              final lastMessage = data['lastMessage'] ?? 'No messages yet.';
                              final lastMessageTime = data['lastMessageTime'] as Timestamp?;
                              
                              return FutureBuilder<UserModel?>(
                                future: _getOtherUser(data['participants']),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return ListTile(title: Text("Loading chat..."), subtitle: Text(lastMessage));
                                  }
                                  if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                                    return ListTile(title: Text("Unknown User"), subtitle: Text(lastMessage));
                                  }
                                  final otherUser = snapshot.data!;
                                  
                                  if (_chatSearch.isNotEmpty && !otherUser.username.toLowerCase().contains(_chatSearch)) {
                                    return Container(); // Hide if not matching search
                                  }

                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(otherUser.username.substring(0, 1).toUpperCase()),
                                    ),
                                    title: Text(otherUser.username),
                                    subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: lastMessageTime != null
                                        ? Text(DateFormat.jm().format(lastMessageTime.toDate()))
                                        : null,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DirectChatScreen(
                                            chatId: chat.id,
                                            otherUserId: otherUser.uid,
                                            otherUserName: otherUser.username,
                                          ),
                                        ),
                                      );
                                    },
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
