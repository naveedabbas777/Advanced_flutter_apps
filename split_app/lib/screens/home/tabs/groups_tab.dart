import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_app/models/group_model.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/screens/groups/create_group_screen.dart';
import 'package:split_app/screens/groups/group_details_screen.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;

class GroupsTab extends StatefulWidget {
  @override
  _GroupsTabState createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  String _groupSearch = '';
  List<GroupModel> _groups = [];
  bool _isLoadingGroups = false;
  String? _groupsError;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    if (!mounted) return;
    setState(() {
      _isLoadingGroups = true;
      _groupsError = null;
    });

    final user =
        Provider.of<AppAuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingGroups = false;
        _groupsError = "User not logged in.";
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('memberIds', arrayContains: user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _groups =
            snapshot.docs.map((doc) => GroupModel.fromFirestore(doc)).toList();
        _isLoadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groupsError = e.toString();
        _isLoadingGroups = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search groups...',
              prefixIcon: Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) =>
                setState(() => _groupSearch = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: _isLoadingGroups
              ? const Center(child: CircularProgressIndicator())
              : _groupsError != null
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error loading groups: $_groupsError',
                          textAlign: TextAlign.center),
                    ))
                  : _groups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No groups yet.',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: Icon(Icons.refresh),
                                label: Text('Reload'),
                                onPressed: _fetchGroups,
                              ),
                              SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text('Create Group'),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              CreateGroupScreen()));
                                },
                              ),
                            ],
                          ),
                        )
                      : Consumer<AppAuthProvider>(
                          builder: (context, authProvider, _) {
                            final currentUser = authProvider.currentUser;
                            if (currentUser == null) {
                              return const Center(
                                  child: Text('User not logged in.'));
                            }

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('groups')
                                  .where('memberIds',
                                      arrayContains: currentUser.uid)
                                  .snapshots(),
                              builder: (context, groupsSnapshot) {
                                if (!groupsSnapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final groups = groupsSnapshot.data!.docs
                                    .map((doc) => GroupModel.fromFirestore(doc))
                                    .where((g) => g.name
                                        .toLowerCase()
                                        .contains(_groupSearch))
                                    .toList();

                                if (groups.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.group_outlined,
                                            size: 48, color: Colors.grey),
                                        SizedBox(height: 12),
                                        Text('No groups yet.',
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  );
                                }

                                return RefreshIndicator(
                                  onRefresh: _fetchGroups,
                                  child: ListView.builder(
                                    itemCount: groups.length,
                                    itemBuilder: (context, index) {
                                      final group = groups[index];
                                      final admin = group.members.firstWhere(
                                        (m) => m.isAdmin,
                                        orElse: () => GroupMember(
                                          userId: '',
                                          username: 'N/A',
                                          email: '',
                                          isAdmin: false,
                                          joinedAt: DateTime.now(),
                                        ),
                                      );
                                      final userId = currentUser.uid;

                                      return StreamBuilder<List<int>>(
                                        stream: _getUnseenCountsStream(
                                            group.id, userId),
                                        builder: (context, snapshot) {
                                          int unseenMessages = 0;
                                          int unseenExpenses = 0;
                                          int unseenNotifications = 0;
                                          if (snapshot.hasData) {
                                            unseenMessages = snapshot.data![0];
                                            unseenExpenses = snapshot.data![1];
                                            unseenNotifications =
                                                snapshot.data![2];
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12.0,
                                                vertical: 6.0),
                                            child: Material(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              elevation: 1,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          GroupDetailsScreen(
                                                              groupId:
                                                                  group.id),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300,
                                                        width: 1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  child: Row(
                                                    children: [
                                                      badges.Badge(
                                                        showBadge:
                                                            unseenMessages > 0,
                                                        badgeContent: Text(
                                                            '$unseenMessages',
                                                            style:
                                                                const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10)),
                                                        position:
                                                            badges.BadgePosition
                                                                .topEnd(
                                                                    top: -8,
                                                                    end: -8),
                                                        child: badges.Badge(
                                                          showBadge:
                                                              unseenExpenses >
                                                                  0,
                                                          badgeContent: Text(
                                                              '$unseenExpenses',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      10)),
                                                          position: badges
                                                                  .BadgePosition
                                                              .bottomEnd(
                                                                  bottom: -8,
                                                                  end: -8),
                                                          child: badges.Badge(
                                                            showBadge:
                                                                unseenNotifications >
                                                                    0,
                                                            badgeContent: Text(
                                                                unseenNotifications >
                                                                        99
                                                                    ? '99+'
                                                                    : '$unseenNotifications',
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10)),
                                                            position: badges
                                                                    .BadgePosition
                                                                .topStart(
                                                                    top: -8,
                                                                    start: -8),
                                                            child: CircleAvatar(
                                                              radius: 26,
                                                              child: Text(
                                                                group.name
                                                                        .isNotEmpty
                                                                    ? group.name
                                                                        .substring(
                                                                            0,
                                                                            1)
                                                                        .toUpperCase()
                                                                    : '?',
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        22,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 14),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    group.name,
                                                                    style:
                                                                        const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          17,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                if (group
                                                                        .lastMessageTime !=
                                                                    null)
                                                                  Text(
                                                                    DateFormat(
                                                                            'hh:mm a')
                                                                        .format(
                                                                            group.lastMessageTime!),
                                                                    style:
                                                                        TextStyle(
                                                                      color: Colors
                                                                          .grey
                                                                          .shade600,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              group.lastMessage ??
                                                                  'No messages yet.',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey
                                                                    .shade700,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              '${group.members.length} Members | Admin: ${admin.username} | ${group.expenseCount} Expenses',
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600),
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
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Stream<List<int>> _getUnseenCountsStream(String groupId, String userId) {
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      return await _getUnseenCounts(groupId, userId);
    }).asyncMap((future) => future);
  }

  Future<List<int>> _getUnseenCounts(String groupId, String userId) async {
    int unseenMessages = 0;
    int unseenExpenses = 0;
    int unseenNotifications = 0;

    // Get last seen for messages
    final chatViewDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('chatViews')
        .doc(userId)
        .get();
    Timestamp? lastSeenMsg;
    if (chatViewDoc.exists) {
      lastSeenMsg = chatViewDoc['lastSeen'] as Timestamp?;
    }
    final msgQuery = await FirebaseFirestore.instance
        .collection('group_messages')
        .where('groupId', isEqualTo: groupId)
        .orderBy('timestamp', descending: false)
        .get();
    if (lastSeenMsg != null) {
      unseenMessages = msgQuery.docs.where((doc) {
        final ts = doc['timestamp'] as Timestamp?;
        final senderId = doc['senderId'] as String?;
        return ts != null &&
            lastSeenMsg != null &&
            ts.toDate().isAfter(lastSeenMsg.toDate()) &&
            senderId != userId;
      }).length;
    } else {
      unseenMessages =
          msgQuery.docs.where((doc) => doc['senderId'] != userId).length;
    }

    // Get last seen for expenses
    final expenseViewDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('expenseViews')
        .doc(userId)
        .get();
    Timestamp? lastSeenExpense;
    if (expenseViewDoc.exists) {
      lastSeenExpense = expenseViewDoc['lastSeen'] as Timestamp?;
    }
    final expenseQuery = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('timestamp', descending: false)
        .get();
    if (lastSeenExpense != null) {
      unseenExpenses = expenseQuery.docs.where((doc) {
        final ts = doc['timestamp'] as Timestamp?;
        final addedBy = doc['addedBy'] as String?;
        return ts != null &&
            lastSeenExpense != null &&
            ts.toDate().isAfter(lastSeenExpense.toDate()) &&
            addedBy != userId;
      }).length;
    } else {
      unseenExpenses =
          expenseQuery.docs.where((doc) => doc['addedBy'] != userId).length;
    }

    // Get unseen group notifications (expense notifications, events, settlements)
    try {
      // Group expense notifications
      final expenseNotificationsQuery = await FirebaseFirestore.instance
          .collection('group_expense_notifications')
          .where('userId', isEqualTo: userId)
          .where('groupId', isEqualTo: groupId)
          .where('seen', isEqualTo: false)
          .get();
      unseenNotifications += expenseNotificationsQuery.docs.length;

      // Group events
      final groupEventsQuery = await FirebaseFirestore.instance
          .collection('group_events')
          .where('userId', isEqualTo: userId)
          .where('groupId', isEqualTo: groupId)
          .where('seen', isEqualTo: false)
          .get();
      unseenNotifications += groupEventsQuery.docs.length;

      // Settlements (unseen settlements for this group)
      // Note: Firestore doesn't support multiple where clauses with OR easily
      // So we'll check settlements separately
      final settlementsFromQuery = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .where('fromUserId', isEqualTo: userId)
          .where('seen', isEqualTo: false)
          .get();
      final settlementsToQuery = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .where('toUserId', isEqualTo: userId)
          .where('seen', isEqualTo: false)
          .get();
      // Combine and deduplicate
      final allSettlements = {
        ...settlementsFromQuery.docs.map((d) => d.id),
        ...settlementsToQuery.docs.map((d) => d.id),
      };
      unseenNotifications += allSettlements.length;
    } catch (e) {
      // If any query fails, just continue with 0 for that type
      print('Error fetching group notifications: $e');
    }

    return [unseenMessages, unseenExpenses, unseenNotifications];
  }
}
