import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../models/group_model.dart';
import '../../services/notification_listener_service.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<GroupMember> members;

  const GroupMembersScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.members,
  }) : super(key: key);

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    final currentUserId = authProvider.currentUser?.uid ?? '';
    final isAdmin = groupProvider.isUserAdmin(currentUserId, widget.members);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Group Members')),
            body: const Center(child: Text('Group not found')),
          );
        }

        final group = GroupModel.fromFirestore(snapshot.data!);
        final currentUserIsAdmin = groupProvider.isUserAdmin(
            currentUserId, group.members);

        // Separate admins and regular members
        final admins = group.members.where((m) => m.isAdmin).toList()
          ..sort((a, b) => a.username.compareTo(b.username));
        final regularMembers = group.members.where((m) => !m.isAdmin).toList()
          ..sort((a, b) => a.username.compareTo(b.username));

        return Scaffold(
          appBar: AppBar(
            title: Text('Members - ${widget.groupName}'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Admins Section
              if (admins.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Admins (${admins.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: admins.map((member) {
                      final isCurrentUser = member.userId == currentUserId;
                      final canManage = currentUserIsAdmin && !isCurrentUser;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            member.username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(member.email),
                        trailing: canManage
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  if (value == 'remove_admin') {
                                    await _updateAdminStatus(
                                        member, false, group);
                                  } else if (value == 'remove_member') {
                                    await _removeMember(member, currentUserId);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'remove_admin',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Text('Remove Admin'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove_member',
                                    child: Row(
                                      children: [
                                        Icon(Icons.remove_circle,
                                            color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Remove Member',
                                            style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : isCurrentUser
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Regular Members Section
              if (regularMembers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.people,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Members (${regularMembers.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: regularMembers.map((member) {
                      final isCurrentUser = member.userId == currentUserId;
                      final canManage = currentUserIsAdmin && !isCurrentUser;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          child: Text(
                            member.username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          member.username,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(member.email),
                        trailing: canManage
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  if (value == 'make_admin') {
                                    await _updateAdminStatus(
                                        member, true, group);
                                  } else if (value == 'remove_member') {
                                    await _removeMember(member, currentUserId);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'make_admin',
                                    child: Row(
                                      children: [
                                        Icon(Icons.admin_panel_settings,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Text('Make Admin'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove_member',
                                    child: Row(
                                      children: [
                                        Icon(Icons.remove_circle,
                                            color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Remove Member',
                                            style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : isCurrentUser
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Empty state
              if (admins.isEmpty && regularMembers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No members found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateAdminStatus(
      GroupMember member, bool isAdmin, GroupModel group) async {
    try {
      final updatedMember = GroupMember(
        userId: member.userId,
        username: member.username,
        email: member.email,
        isAdmin: isAdmin,
        joinedAt: member.joinedAt,
      );

      final updatedMembers = group.members
          .map((m) => m.userId == member.userId ? updatedMember.toMap() : m.toMap())
          .toList();

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'members': updatedMembers});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdmin
                ? '${member.username} promoted to admin.'
                : 'Admin rights removed from ${member.username}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update admin status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(GroupMember member, String removedBy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove ${member.username} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final groupProvider = Provider.of<GroupProvider>(context, listen: false);
        await groupProvider.removeMember(
          groupId: widget.groupId,
          userId: member.userId,
          removedBy: removedBy,
        );

        // Refresh notification listeners
        final authProvider =
            Provider.of<AppAuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          await NotificationListenerService().refreshUserGroups();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.username} removed from group.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove member: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}






