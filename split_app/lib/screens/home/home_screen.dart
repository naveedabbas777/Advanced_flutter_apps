import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/group_provider.dart';
import 'package:split_app/models/group_model.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_details_screen.dart';
import '../direct_chat/direct_chat_screen.dart';
import '../direct_chat/user_search_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'package:intl/intl.dart';
import 'archived_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _groupSearch = '';
  String _chatSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    authProvider.loadPinned();

    return Scaffold(
      appBar: AppBar(
        title: Text('Split App'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(
              text: 'Groups',
              icon: Icon(Icons.group, size: 30),
            ),
            Tab(
              text: 'Messages',
              icon: Icon(Icons.chat_bubble, size: 30),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.archive_outlined),
            tooltip: 'Archived',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ArchivedScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.mail_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/invitations');
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Groups Tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Your Groups',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search groups...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() => _groupSearch = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<GroupModel>>(
                  stream: groupProvider.getUserGroupsStream(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final groups = snapshot.data;
                    if (groups == null || groups.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No groups yet.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Create a new group to get started!',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    // Sort groups by name (case-insensitive)
                    final sortedGroups = [
                      ...groups.where((g) => authProvider.pinnedGroups.contains(g.id) && !authProvider.archivedGroups.contains(g.id)),
                      ...groups.where((g) => !authProvider.pinnedGroups.contains(g.id) && !authProvider.archivedGroups.contains(g.id)),
                    ];
                    sortedGroups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    final filteredGroups = sortedGroups.where((g) => g.name.toLowerCase().contains(_groupSearch)).toList();
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        String groupId = group.id;
                        String groupName = group.name;
                        return Card(
                          elevation: 3,
                          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16.0),
                            leading: group.photoUrl != null
                                ? CircleAvatar(backgroundImage: NetworkImage(group.photoUrl!), radius: 24)
                                : CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    radius: 24,
                                    child: Text(
                                      groupName.substring(0, 1).toUpperCase(),
                                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ),
                            title: Text(
                              groupName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: group.members.map((member) {
                                    return Chip(
                                      label: Text(member.username),
                                      avatar: CircleAvatar(
                                          child: Text(member.username.substring(0, 1).toUpperCase())),
                                      backgroundColor: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                                      labelStyle: Theme.of(context).textTheme.bodySmall,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('groups')
                                      .doc(groupId)
                                      .collection('expenses')
                                      .orderBy('timestamp', descending: true)
                                      .snapshots(),
                                  builder: (context, expenseSnapshot) {
                                    if (expenseSnapshot.hasError) {
                                      return Text('Error loading expenses', style: TextStyle(color: Colors.red));
                                    }
                                    if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                                      return Text('Loading group summary...');
                                    }
                                    double totalSpent = 0.0;
                                    double userShare = 0.0;
                                    double userOwes = 0.0;
                                    double userIsOwed = 0.0;
                                    final expenses = expenseSnapshot.data!.docs;
                                    final currentUserUid = user.uid;
                                    for (var expenseDoc in expenses) {
                                      var expenseData = expenseDoc.data() as Map<String, dynamic>;
                                      double amount = (expenseData['amount'] as num?)?.toDouble() ?? 0.0;
                                      String paidBy = expenseData['paidBy']?.toString() ?? '';
                                      String splitType = expenseData['splitType']?.toString() ?? 'equal';
                                      dynamic splitData = expenseData['splitData'];
                                      totalSpent += amount;
                                      double currentUserShare = 0.0;
                                      if (splitType == 'equal') {
                                        final numMembers = group.members.length;
                                        currentUserShare = numMembers > 0 ? amount / numMembers : 0.0;
                                      } else if (splitType == 'custom' && splitData is Map<String, dynamic>) {
                                        currentUserShare = (splitData[currentUserUid] as num?)?.toDouble() ?? 0.0;
                                      }
                                      if (paidBy == currentUserUid) {
                                        userIsOwed += (amount - currentUserShare);
                                      } else {
                                        if ((splitType == 'equal' && splitData is List && splitData.contains(currentUserUid)) ||
                                            (splitType == 'custom' && splitData is Map && splitData.containsKey(currentUserUid))) {
                                          userOwes += currentUserShare;
                                        }
                                      }
                                    }
                                    double balance = userIsOwed - userOwes;
                                    Color balanceColor = balance == 0
                                        ? Colors.grey
                                        : (balance > 0 ? Colors.green : Colors.red);
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.attach_money, size: 16, color: Theme.of(context).colorScheme.primary),
                                            SizedBox(width: 4),
                                            Text('Total:  \${totalSpent.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
                                            SizedBox(width: 12),
                                            Icon(Icons.group, size: 16, color: Theme.of(context).colorScheme.primary),
                                            SizedBox(width: 4),
                                            Text('Members: ${group.members.length}', style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Your Balance:  \${balance.toStringAsFixed(2)}',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: balanceColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            trailing: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(groupId)
                                  .collection('chatViews')
                                  .doc(user.uid)
                                  .snapshots(),
                              builder: (context, chatViewSnapshot) {
                                Timestamp? lastSeen;
                                if (chatViewSnapshot.hasData && chatViewSnapshot.data!.exists) {
                                  lastSeen = chatViewSnapshot.data!.get('lastSeen') as Timestamp?;
                                }
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('groups')
                                      .doc(groupId)
                                      .collection('messages')
                                      .orderBy('timestamp', descending: false)
                                      .snapshots(),
                                  builder: (context, msgSnapshot) {
                                    int unreadCount = 0;
                                    if (msgSnapshot.hasData && lastSeen != null) {
                                      unreadCount = msgSnapshot.data!.docs.where((doc) {
                                        final ts = doc['timestamp'] as Timestamp?;
                                        return ts != null && ts.toDate().isAfter(lastSeen!.toDate());
                                      }).length;
                                    } else if (msgSnapshot.hasData && lastSeen == null) {
                                      unreadCount = msgSnapshot.data!.docs.length;
                                    }
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            authProvider.pinnedGroups.contains(groupId) ? Icons.push_pin : Icons.push_pin_outlined,
                                            color: authProvider.pinnedGroups.contains(groupId) ? Theme.of(context).colorScheme.primary : Colors.grey,
                                          ),
                                          tooltip: authProvider.pinnedGroups.contains(groupId) ? 'Unpin Group' : 'Pin Group',
                                          onPressed: () => authProvider.togglePinGroup(groupId),
                                        ),
                                        badges.Badge(
                                          showBadge: unreadCount > 0,
                                          badgeContent: Text('$unreadCount', style: TextStyle(color: Colors.white, fontSize: 10)),
                                          position: badges.BadgePosition.topEnd(top: -8, end: -8),
                                          child: Icon(Icons.arrow_forward_ios),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/group-details',
                                arguments: {'groupId': groupId, 'groupName': groupName},
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Direct Messages Tab
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Messages',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() => _chatSearch = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('direct_chats')
                      .where('participants', arrayContains: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final chats = snapshot.data?.docs ?? [];
                    if (chats.isEmpty) {
                      return Center(child: Text('No direct messages yet.'));
                    }
                    // Sort chats by most recent message time (descending)
                    final sortedChats = [
                      ...chats.where((chat) => authProvider.pinnedChats.contains(chat.id) && !authProvider.archivedChats.contains(chat.id)),
                      ...chats.where((chat) => !authProvider.pinnedChats.contains(chat.id) && !authProvider.archivedChats.contains(chat.id)),
                    ];
                    sortedChats.sort((a, b) {
                      final aTime = a['lastMessageTime'] as Timestamp?;
                      final bTime = b['lastMessageTime'] as Timestamp?;
                      if (aTime != null && bTime != null) {
                        return bTime.compareTo(aTime); // Descending order
                      } else if (aTime != null) {
                        return -1;
                      } else if (bTime != null) {
                        return 1;
                      } else {
                        return b.id.compareTo(a.id);
                      }
                    });
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      itemCount: sortedChats.length,
                      itemBuilder: (context, index) {
                        final chat = sortedChats[index];
                        final participants = List<String>.from(chat['participants']);
                        final otherUserId = participants.firstWhere((id) => id != user.uid, orElse: () => '');
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                          builder: (context, userSnapshot) {
                            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                            final otherUserName = userData?['username'] ?? 'Unknown';
                            final photoUrl = userData?['photoUrl'] as String?;
                            return Card(
                              elevation: 3,
                              margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16.0),
                                leading: photoUrl != null
                                    ? CircleAvatar(backgroundImage: NetworkImage(photoUrl), radius: 24)
                                    : CircleAvatar(
                                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                        radius: 24,
                                        child: Text(
                                          otherUserName.substring(0, 1).toUpperCase(),
                                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                                        ),
                                      ),
                                title: Text(otherUserName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                                      builder: (context, userSnap) {
                                        if (!userSnap.hasData || !userSnap.data!.exists) return SizedBox.shrink();
                                        final userData = userSnap.data!.data() as Map<String, dynamic>?;
                                        final lastActive = userData?['lastActive'] as Timestamp?;
                                        String status = '';
                                        if (lastActive != null) {
                                          final lastActiveDate = lastActive.toDate();
                                          final now = DateTime.now();
                                          if (now.difference(lastActiveDate).inMinutes < 2) {
                                            status = 'Online';
                                          } else {
                                            status = 'Last seen: ' + DateFormat('yyyy-MM-dd HH:mm').format(lastActiveDate);
                                          }
                                        }
                                        return Text(status, style: TextStyle(fontSize: 12, color: status == 'Online' ? Colors.green : Colors.grey));
                                      },
                                    ),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('direct_chats')
                                          .doc(chat.id)
                                          .collection('messages')
                                          .orderBy('timestamp', descending: true)
                                          .limit(1)
                                          .snapshots(),
                                      builder: (context, msgSnapshot) {
                                        if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                                          final msg = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                                          return Text('${msg['senderName']}: ${msg['text']}');
                                        }
                                        return Text('No messages yet.');
                                      },
                                    ),
                                  ],
                                ),
                                trailing: StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('direct_chats')
                                      .doc(chat.id)
                                      .collection('chatViews')
                                      .doc(user.uid)
                                      .snapshots(),
                                  builder: (context, chatViewSnapshot) {
                                    Timestamp? lastSeen;
                                    if (chatViewSnapshot.hasData && chatViewSnapshot.data!.exists) {
                                      lastSeen = chatViewSnapshot.data!.get('lastSeen') as Timestamp?;
                                    }
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('direct_chats')
                                          .doc(chat.id)
                                          .collection('messages')
                                          .orderBy('timestamp', descending: false)
                                          .snapshots(),
                                      builder: (context, msgSnapshot) {
                                        int unreadCount = 0;
                                        if (msgSnapshot.hasData && lastSeen != null) {
                                          unreadCount = msgSnapshot.data!.docs.where((doc) {
                                            final ts = doc['timestamp'] as Timestamp?;
                                            return ts != null && ts.toDate().isAfter(lastSeen!.toDate());
                                          }).length;
                                        } else if (msgSnapshot.hasData && lastSeen == null) {
                                          unreadCount = msgSnapshot.data!.docs.length;
                                        }
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                authProvider.pinnedChats.contains(chat.id) ? Icons.push_pin : Icons.push_pin_outlined,
                                                color: authProvider.pinnedChats.contains(chat.id) ? Theme.of(context).colorScheme.primary : Colors.grey,
                                              ),
                                              tooltip: authProvider.pinnedChats.contains(chat.id) ? 'Unpin Chat' : 'Pin Chat',
                                              onPressed: () => authProvider.togglePinChat(chat.id),
                                            ),
                                            badges.Badge(
                                              showBadge: unreadCount > 0,
                                              badgeContent: Text('$unreadCount', style: TextStyle(color: Colors.white, fontSize: 10)),
                                              position: badges.BadgePosition.topEnd(top: -8, end: -8),
                                              child: SizedBox(width: 0, height: 0),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
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
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          if (_tabController.index == 0) {
            // Groups tab
            return FloatingActionButton.extended(
              icon: Icon(Icons.add),
              label: Text('Create Group'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CreateGroupScreen()));
              },
            );
          } else {
            // Direct Messages tab
            return FloatingActionButton(
              child: Icon(Icons.chat),
              tooltip: 'New Direct Chat',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => UserSearchScreen(currentUserId: user.uid)),
                );
              },
            );
          }
        },
      ),
    );
  }
} 