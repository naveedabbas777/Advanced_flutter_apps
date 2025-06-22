import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';

class UserInviteSearchScreen extends StatefulWidget {
  final String groupId;
  final List<String> currentMemberIds;
  final String currentUserId;
  const UserInviteSearchScreen({
    Key? key,
    required this.groupId,
    required this.currentMemberIds,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<UserInviteSearchScreen> createState() => _UserInviteSearchScreenState();
}

class _UserInviteSearchScreenState extends State<UserInviteSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _results = [];
  bool _isLoading = false;

  Future<void> _searchUsers() async {
    setState(() { _isLoading = true; });
    final query = _searchController.text.trim().toLowerCase();
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
      _results = allDocs
        .where((doc) => doc.id != widget.currentUserId && !widget.currentMemberIds.contains(doc.id))
        .toList();
      _isLoading = false;
    });
  }

  void _inviteUser(DocumentSnapshot userDoc) async {
    final userData = userDoc.data() as Map<String, dynamic>;
    final email = userData['email'];
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final inviterUsername = authProvider.currentUserModel?.username ?? '';
    final inviterEmail = authProvider.currentUserModel?.email ?? '';
    try {
      await groupProvider.inviteUserToGroup(
        groupId: widget.groupId,
        invitedBy: widget.currentUserId,
        invitedByUsername: inviterUsername,
        invitedByEmail: inviterEmail,
        invitedUserEmail: email,
      );
      if (groupProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(groupProvider.error!), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitation: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Member')),
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
                          onTap: () => _inviteUser(userDoc),
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