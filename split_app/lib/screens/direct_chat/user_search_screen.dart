import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'direct_chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  final String currentUserId;
  const UserSearchScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _results = [];
  bool _isLoading = false;

  Future<void> _searchUsers() async {
    setState(() { _isLoading = true; });
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() { _results = []; _isLoading = false; });
      return;
    }
    final usersByEmail = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: query)
        .get();
    final usersByUsername = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: query)
        .get();
    final allDocs = {...usersByEmail.docs, ...usersByUsername.docs};
    setState(() {
      _results = allDocs.where((doc) => doc.id != widget.currentUserId).toList();
      _isLoading = false;
    });
  }

  void _startChat(String otherUserId, String otherUserName) async {
    final currentUserId = widget.currentUserId;
    final chatId = [currentUserId, otherUserId]..sort();
    final chatDocId = chatId.join('_');
    // Fetch current user's username
    final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final currentUserName = currentUserDoc['username'] ?? '';
    // Ensure chat document exists with usernames
    final chatDoc = FirebaseFirestore.instance.collection('direct_chats').doc(chatDocId);
    await chatDoc.set({
      'participants': [currentUserId, otherUserId],
      'participantUsernames': {
        currentUserId: currentUserName,
        otherUserId: otherUserName,
      },
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessage': '',
    }, SetOptions(merge: true));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          chatId: chatDocId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start New Chat')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by username or email',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchUsers,
                  child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No users found.'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final userDoc = _results[index];
                        final userData = userDoc.data() as Map<String, dynamic>;
                        final userName = userData['username'] ?? userData['email'] ?? 'Unknown';
                        return ListTile(
                          leading: CircleAvatar(child: Text(userName.substring(0, 1).toUpperCase())),
                          title: Text(userName),
                          subtitle: Text(userData['email'] ?? ''),
                          onTap: () => _startChat(userDoc.id, userName),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 