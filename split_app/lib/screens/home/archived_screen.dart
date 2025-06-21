import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/group_model.dart';
import '../groups/group_details_screen.dart';
import '../direct_chat/direct_chat_screen.dart';

class ArchivedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final user = authProvider.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Archived')),
      body: ListView(
        children: [
          if (authProvider.archivedGroups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Archived Groups', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...authProvider.archivedGroups.map((groupId) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('groups').doc(groupId).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return SizedBox.shrink();
                final group = GroupModel.fromFirestore(snapshot.data!);
                return Card(
                  child: ListTile(
                    leading: group.photoUrl != null
                        ? CircleAvatar(backgroundImage: NetworkImage(group.photoUrl!))
                        : CircleAvatar(child: Text(group.name.substring(0, 1).toUpperCase())),
                    title: Text(group.name),
                    trailing: IconButton(
                      icon: Icon(Icons.unarchive),
                      tooltip: 'Unarchive',
                      onPressed: () => authProvider.toggleArchiveGroup(group.id),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailsScreen(groupId: group.id),
                        ),
                      );
                    },
                  ),
                );
              },
            )),
          ],
          if (authProvider.archivedChats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Archived Direct Chats', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...authProvider.archivedChats.map((chatId) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('direct_chats').doc(chatId).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return SizedBox.shrink();
                final chat = snapshot.data!;
                final participants = List<String>.from(chat['participants']);
                final otherUserId = participants.firstWhere((id) => id != user.uid, orElse: () => '');
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                  builder: (context, userSnapshot) {
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    final otherUserName = userData?['username'] ?? 'Unknown';
                    final photoUrl = userData?['photoUrl'] as String?;
                    return Card(
                      child: ListTile(
                        leading: photoUrl != null
                            ? CircleAvatar(backgroundImage: NetworkImage(photoUrl))
                            : CircleAvatar(child: Text(otherUserName.substring(0, 1).toUpperCase())),
                        title: Text(otherUserName),
                        trailing: IconButton(
                          icon: Icon(Icons.unarchive),
                          tooltip: 'Unarchive',
                          onPressed: () => authProvider.toggleArchiveChat(chatId),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                chatId: chatId,
                                otherUserId: otherUserId,
                                otherUserName: otherUserName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            )),
          ],
          if (authProvider.archivedGroups.isEmpty && authProvider.archivedChats.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No archived groups or chats.'),
            )),
        ],
      ),
    );
  }
} 