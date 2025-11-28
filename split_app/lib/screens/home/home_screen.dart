import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../groups/create_group_screen.dart';
import '../direct_chat/user_search_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'archived_screen.dart';
import 'package:lottie/lottie.dart';

// Import the tab bodies as separate widgets
import 'tabs/groups_tab.dart';
import 'tabs/messages_tab.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    GroupsTab(),
    MessagesTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Stream<int> _getTotalUnreadMessagesStream(
      List<DocumentSnapshot> chats, String userId) {
    if (chats.isEmpty) {
      return Stream.value(0);
    }

    // Create a stream that periodically calculates unread messages
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      int totalUnread = 0;
      for (var chatDoc in chats) {
        final chatId = chatDoc.id;

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
          final unreadMessages = messagesQuery.docs.where((doc) {
            final ts = doc.data()['timestamp'] as Timestamp?;
            final senderId = doc.data()['senderId'] as String?;
            return ts != null &&
                ts.toDate().isAfter(lastSeen!.toDate()) &&
                senderId != userId;
          }).length;
          totalUnread += unreadMessages;
        } else {
          final unreadMessages = messagesQuery.docs
              .where((doc) => doc.data()['senderId'] != userId)
              .length;
          totalUnread += unreadMessages;
        }
      }
      return totalUnread;
    }).asyncMap((future) => future);
  }

  Stream<int> _getTotalUnreadGroupsStream(
      List<DocumentSnapshot> groups, String userId) {
    if (groups.isEmpty) {
      return Stream.value(0);
    }

    // Create a stream that periodically calculates total unread (messages + expenses)
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      int totalUnread = 0;
      for (var groupDoc in groups) {
        final groupId = groupDoc.id;

        // Get unread messages
        final chatViewDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('chatViews')
            .doc(userId)
            .get();

        Timestamp? lastSeenMsg;
        if (chatViewDoc.exists) {
          lastSeenMsg = chatViewDoc.data()?['lastSeen'] as Timestamp?;
        }

        final messagesQuery = await FirebaseFirestore.instance
            .collection('group_messages')
            .where('groupId', isEqualTo: groupId)
            .get();

        if (lastSeenMsg != null) {
          final unreadMessages = messagesQuery.docs.where((doc) {
            final ts = doc.data()['timestamp'] as Timestamp?;
            final senderId = doc.data()['senderId'] as String?;
            return ts != null &&
                ts.toDate().isAfter(lastSeenMsg!.toDate()) &&
                senderId != userId;
          }).length;
          totalUnread += unreadMessages;
        } else {
          final unreadMessages = messagesQuery.docs
              .where((doc) => doc.data()['senderId'] != userId)
              .length;
          totalUnread += unreadMessages;
        }

        // Get unread expenses
        final expenseViewDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('expenseViews')
            .doc(userId)
            .get();

        Timestamp? lastSeenExpense;
        if (expenseViewDoc.exists) {
          lastSeenExpense = expenseViewDoc.data()?['lastSeen'] as Timestamp?;
        }

        final expensesQuery = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('expenses')
            .get();

        if (lastSeenExpense != null) {
          final unreadExpenses = expensesQuery.docs.where((doc) {
            final ts = doc.data()['timestamp'] as Timestamp?;
            final addedBy = doc.data()['addedBy'] as String?;
            return ts != null &&
                ts.toDate().isAfter(lastSeenExpense!.toDate()) &&
                addedBy != userId;
          }).length;
          totalUnread += unreadExpenses;
        } else {
          final unreadExpenses = expensesQuery.docs
              .where((doc) => doc.data()['addedBy'] != userId)
              .length;
          totalUnread += unreadExpenses;
        }
      }
      return totalUnread;
    }).asyncMap((future) => future);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Groups' : 'Messages'),
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
          Consumer<AppAuthProvider>(
            builder: (context, authProvider, _) {
              final userId = authProvider.currentUser?.uid;
              if (userId == null) {
                return IconButton(
                  icon: const Icon(Icons.mail_outline),
                  tooltip: 'Invitations',
                  onPressed: () {
                    Navigator.pushNamed(context, '/invitations');
                  },
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('group_invitations')
                    .where('invitedUserId', isEqualTo: userId)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  int invitationCount = 0;
                  if (snapshot.hasData) {
                    invitationCount = snapshot.data!.docs.length;
                  }
                  return badges.Badge(
                    showBadge: invitationCount > 0,
                    badgeContent: Text(
                      invitationCount > 99 ? '99+' : invitationCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    position: badges.BadgePosition.topEnd(top: -8, end: -8),
                    child: IconButton(
                      icon: const Icon(Icons.mail_outline),
                      tooltip: 'Invitations',
                      onPressed: () {
                        Navigator.pushNamed(context, '/invitations');
                      },
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/lotties/homebg3.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          Center(
            child: _widgetOptions.elementAt(_selectedIndex),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CreateGroupScreen()));
              },
              child: const Icon(Icons.add),
              tooltip: 'Create Group',
            )
          : FloatingActionButton(
              onPressed: () {
                final authProvider =
                    Provider.of<AppAuthProvider>(context, listen: false);
                final currentUserId = authProvider.currentUser?.uid;
                if (currentUserId != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              UserSearchScreen(currentUserId: currentUserId)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          "Cannot start a new chat. User not logged in.")));
                }
              },
              child: const Icon(Icons.message),
              tooltip: 'New Message',
            ),
      bottomNavigationBar: Consumer<AppAuthProvider>(
        builder: (context, authProvider, _) {
          final userId = authProvider.currentUser?.uid;

          return BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: userId != null
                    ? StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('groups')
                            .where('memberIds', arrayContains: userId)
                            .snapshots(),
                        builder: (context, groupsSnapshot) {
                          if (!groupsSnapshot.hasData) {
                            return const Icon(Icons.group);
                          }

                          final groups = groupsSnapshot.data!.docs;
                          if (groups.isEmpty) {
                            return const Icon(Icons.group);
                          }

                          return StreamBuilder<int>(
                            stream: _getTotalUnreadGroupsStream(groups, userId),
                            builder: (context, unreadSnapshot) {
                              int totalUnread = unreadSnapshot.data ?? 0;
                              return badges.Badge(
                                showBadge: totalUnread > 0,
                                badgeContent: Text(
                                  totalUnread > 99
                                      ? '99+'
                                      : totalUnread.toString(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                                position: badges.BadgePosition.topEnd(
                                    top: -8, end: -8),
                                child: const Icon(Icons.group),
                              );
                            },
                          );
                        },
                      )
                    : const Icon(Icons.group),
                label: 'Groups',
              ),
              BottomNavigationBarItem(
                icon: userId != null
                    ? StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('direct_chats')
                            .where('participants', arrayContains: userId)
                            .snapshots(),
                        builder: (context, chatsSnapshot) {
                          if (!chatsSnapshot.hasData) {
                            return const Icon(Icons.chat_bubble);
                          }

                          final chats = chatsSnapshot.data!.docs;
                          if (chats.isEmpty) {
                            return const Icon(Icons.chat_bubble);
                          }

                          // Use StreamBuilder to calculate unread messages in real-time
                          return StreamBuilder<int>(
                            stream:
                                _getTotalUnreadMessagesStream(chats, userId),
                            builder: (context, unreadSnapshot) {
                              int unreadCount = unreadSnapshot.data ?? 0;
                              return badges.Badge(
                                showBadge: unreadCount > 0,
                                badgeContent: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                                position: badges.BadgePosition.topEnd(
                                    top: -8, end: -8),
                                child: const Icon(Icons.chat_bubble),
                              );
                            },
                          );
                        },
                      )
                    : const Icon(Icons.chat_bubble),
                label: 'Messages',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          );
        },
      ),
    );
  }
}
