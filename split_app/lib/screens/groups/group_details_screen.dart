import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../services/group_service.dart';
// import '../../services/expense_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import 'package:split_app/models/group_model.dart';
import 'package:split_app/screens/expenses/add_expense_screen.dart';
import 'package:split_app/screens/members/add_member_screen.dart';
import 'group_chat_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';

// Re-applying to refresh parsing due to persistent 'Expected an identifier' error.
class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    final user = authProvider.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Group Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Group not found.', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.home),
                    label: Text('Back to Home'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          );
        }
        final group = GroupModel.fromFirestore(snapshot.data!);
        String groupName = group.name;
        List<GroupMember> groupMembers = group.members;
        final isAdmin = groupProvider.isUserAdmin(user.uid, group.members);
        return Scaffold(
          appBar: AppBar(
            title: Text(groupName),
            actions: [
              IconButton(
                icon: Icon(Icons.person_add_alt_1),
                tooltip: 'Invite Member',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddMemberScreen(groupId: group.id),
                    ),
                  );
                },
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(group.id)
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
                        .doc(group.id)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, msgSnapshot) {
                      int unseenCount = 0;
                      if (msgSnapshot.hasData && lastSeen != null) {
                        unseenCount = msgSnapshot.data!.docs.where((doc) {
                          final ts = doc['timestamp'] as Timestamp?;
                          return ts != null && ts.toDate().isAfter(lastSeen!.toDate());
                        }).length;
                      } else if (msgSnapshot.hasData && lastSeen == null) {
                        unseenCount = msgSnapshot.data!.docs.length;
                      }
                      return badges.Badge(
                        showBadge: unseenCount > 0,
                        badgeContent: Text('$unseenCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        position: badges.BadgePosition.topEnd(top: -8, end: -8),
                        child: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          tooltip: 'Group Chat',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupChatScreen(
                                  groupId: group.id,
                                  groupName: group.name,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showGroupSettings(context, group, isAdmin, user.uid, groupProvider),
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: group.photoUrl != null
                          ? NetworkImage(group.photoUrl!)
                          : null,
                      child: group.photoUrl == null
                          ? Text(
                              groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                    if (isAdmin)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: null,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Group Members Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Group Members',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (groupProvider.isUserAdmin(user.uid, group.members))
                              Text(
                                'Admin',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          children: groupMembers.map((member) {
                            final isCurrentUser = member.userId == user.uid;
                            final canManage = isAdmin && !isCurrentUser;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                              child: GestureDetector(
                                onTap: canManage
                                    ? () async {
                                        final action = await showMenu<String>(
                                          context: context,
                                          position: RelativeRect.fromLTRB(100, 100, 0, 0),
                                          items: [
                                            if (!member.isAdmin)
                                              const PopupMenuItem(
                                                value: 'make_admin',
                                                child: Text('Make Admin'),
                                              ),
                                            if (member.isAdmin)
                                              const PopupMenuItem(
                                                value: 'remove_admin',
                                                child: Text('Remove Admin'),
                                              ),
                                          ],
                                        );
                                        if (action == 'make_admin' || action == 'remove_admin') {
                                          // Update isAdmin in Firestore
                                          final updatedMember = GroupMember(
                                            userId: member.userId,
                                            username: member.username,
                                            email: member.email,
                                            isAdmin: action == 'make_admin',
                                            joinedAt: member.joinedAt,
                                          );
                                          final updatedMembers = groupMembers.map((m) =>
                                            m.userId == member.userId ? updatedMember.toMap() : m.toMap()
                                          ).toList();
                                          await FirebaseFirestore.instance.collection('groups').doc(group.id).update({
                                            'members': updatedMembers,
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(action == 'make_admin' ? 'Promoted to admin.' : 'Admin rights removed.')),
                                          );
                                        }
                                      }
                                    : null,
                                child: Chip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          member.username,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (member.isAdmin) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          'Admin',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  avatar: CircleAvatar(
                                    child: Text(member.username.substring(0, 1).toUpperCase()),
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                  deleteIcon: groupProvider.isUserAdmin(user.uid, group.members) && 
                                            member.userId != user.uid ? 
                                            const Icon(Icons.remove_circle_outline) : null,
                                  onDeleted: groupProvider.isUserAdmin(user.uid, group.members) && 
                                            member.userId != user.uid ?
                                            () async {
                                              try {
                                                await groupProvider.removeMember(
                                                  groupId: widget.groupId,
                                                  userId: member.userId,
                                                  removedBy: user.uid,
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(e.toString())),
                                                );
                                              }
                                            } : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Group Dashboard Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Group Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              FutureBuilder<Map<String, double>>(
                future: groupProvider.calculateGroupBalances(group.id, group.members),
                builder: (context, balancesSnapshot) {
                  if (balancesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (balancesSnapshot.hasError) {
                    return Text('Error loading balances: ${balancesSnapshot.error}', style: TextStyle(color: Colors.red));
                  }

                  final balances = balancesSnapshot.data ?? {};
                  double totalGroupExpenses = 0.0; // Calculate total expenses separately

                  // Recalculate total group expenses from the raw expense stream for accuracy
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('groups')
                        .doc(widget.groupId)
                        .collection('expenses')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, expenseSnapshot) {
                      if (expenseSnapshot.hasError) {
                        return Text('Error loading expenses for total: ${expenseSnapshot.error}', style: TextStyle(color: Colors.red));
                      }
                      if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink(); // Hide while waiting, balances already loading
                      }

                      totalGroupExpenses = expenseSnapshot.data!.docs.fold(0.0, (sum, doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final amount = data['amount'];
                        if (amount == null) return sum;
                        return sum + (amount is num ? amount.toDouble() : 0.0);
                      });

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Group Expenses: \$${totalGroupExpenses.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Individual Balances:',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              // List individual balances
                              ...groupMembers.map((member) {
                                final balance = balances[member.userId] ?? 0.0;
                                Color balanceColor = balance == 0
                                    ? Colors.grey
                                    : (balance > 0 ? Colors.green : Colors.red);
                                String balanceText = balance >= 0
                                    ? 'Gets back: \$${balance.toStringAsFixed(2)}'
                                    : 'Owes: \$${balance.abs().toStringAsFixed(2)}';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          member.username,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(balanceText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: balanceColor, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // Expenses by Category
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Expenses by Category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('expenses')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No expenses to show.'),
                    );
                  }
                  final expenses = snapshot.data!.docs;
                  final Map<String, double> categoryTotals = {};
                  for (var doc in expenses) {
                    final data = doc.data() as Map<String, dynamic>;
                    final category = data['category'] ?? 'Other';
                    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                    categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
                  }
                  final colors = [
                    Colors.blue,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                    Colors.red,
                    Colors.teal,
                    Colors.brown,
                    Colors.pink,
                  ];
                  final categoryList = categoryTotals.entries.toList();
                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              for (int i = 0; i < categoryList.length; i++)
                                PieChartSectionData(
                                  color: colors[i % colors.length],
                                  value: categoryList[i].value,
                                  title: categoryList[i].key,
                                  radius: 60,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...categoryList.map((e) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(width: 16, height: 16, color: colors[categoryList.indexOf(e) % colors.length]),
                                  const SizedBox(width: 8),
                                  Text(e.key, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                              Text('₹${e.value.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          )),
                    ],
                  );
                },
              ),
              // Expenses History Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Expenses History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('expenses')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, expenseSnapshot) {
                    if (expenseSnapshot.hasError) {
                      return Center(
                          child: Text('Error: ${expenseSnapshot.error}'));
                    }

                    if (expenseSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!expenseSnapshot.hasData ||
                        expenseSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.money_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses yet.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first expense to track spending in this group!',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: expenseSnapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var expense = expenseSnapshot.data!.docs[index];
                        var expenseData =
                            expense.data() as Map<String, dynamic>;

                        String description =
                            expenseData['description']?.toString() ?? 'No Description';
                        double amount = 0.0;
                        if (expenseData['amount'] != null) {
                          final rawAmount = expenseData['amount'];
                          amount = rawAmount is num ? rawAmount.toDouble() : 0.0;
                        }
                        String paidByUserId = expenseData['paidBy']?.toString() ?? '';
                        Timestamp timestamp =
                            expenseData['timestamp'] as Timestamp? ?? Timestamp.fromDate(DateTime.now());

                        String splitType = expenseData['splitType']?.toString() ?? 'equal';
                        dynamic splitData;
                        if (splitType == 'custom') {
                          final rawData = expenseData['splitData'] as Map<String, dynamic>?;
                          if (rawData != null) {
                            splitData = rawData.map(
                              (k, v) {
                                if (v == null) return MapEntry(k, 0.0);
                                return MapEntry(k, (v is num ? v.toDouble() : 0.0));
                              }
                            );
                          }
                        } else {
                          splitData = (expenseData['splitData'] as List<dynamic>?)?.map((e) => e.toString()).toList();
                        }

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(paidByUserId)
                              .get(),
                          builder: (context, userSnapshot) {
                            String paidByUsername = 'Unknown User';
                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              paidByUsername = userSnapshot.data!['username'] ?? userSnapshot.data!['email'] ?? 'Unknown User';
                            }

                            String splitInfo = 'Equal Split';
                            if (splitType == 'custom') {
                              splitInfo = 'Custom Split';
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10.0),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: splitType == 'custom'
                                  ? ExpansionTile(
                                      title: Text(description),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Paid by: $paidByUsername'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Date: ${timestamp.toDate().toLocal().day}/${timestamp.toDate().toLocal().month}/${timestamp.toDate().toLocal().year}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          if (expenseData['notes'] != null &&
                                              expenseData['notes'].isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text(
                                                'Notes: ${expenseData['notes']}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Split: $splitInfo',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                      trailing: Text(
                                        '\$' + amount.toStringAsFixed(2),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0, vertical: 8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Custom Split Details:',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
                                              ...splitData.entries.map<Widget>((entry) {
                                                final memberName = group.members
                                                    .firstWhere((m) =>
                                                        m.userId == entry.key,
                                                        orElse: () => GroupMember(
                                                            userId: entry.key,
                                                            username: 'Unknown',
                                                            email: 'unknown@example.com',
                                                            isAdmin: false,
                                                            joinedAt: DateTime.now()))
                                                    .username;
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                      vertical: 2.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          memberName,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Text('\$${(entry.value as double).toStringAsFixed(2)}'),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListTile(
                                      title: Text(description),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Paid by: $paidByUsername'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Date: ${timestamp.toDate().toLocal().day}/${timestamp.toDate().toLocal().month}/${timestamp.toDate().toLocal().year}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          if (expenseData['notes'] != null &&
                                              expenseData['notes'].isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text(
                                                'Notes: ${expenseData['notes']}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Split: $splitInfo',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                      trailing: Text(
                                        '\$' + amount.toStringAsFixed(2),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      onTap: () {
                                        // TODO: Navigate to expense details or edit screen
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/add-expense',
                arguments: {'groupId': widget.groupId, 'groupName': groupName},
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
          ),
        );
      },
    );
  }

  void _showGroupSettings(BuildContext context, GroupModel group, bool isAdmin, String userId, GroupProvider groupProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Rename Group'),
                  onTap: () async {
                    Navigator.pop(context);
                    final newName = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        final controller = TextEditingController(text: group.name);
                        return AlertDialog(
                          title: const Text('Rename Group'),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(labelText: 'New group name'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, controller.text.trim()),
                              child: const Text('Rename'),
                            ),
                          ],
                        );
                      },
                    );
                    if (newName != null && newName.isNotEmpty && newName != group.name) {
                      await FirebaseFirestore.instance.collection('groups').doc(group.id).update({'name': newName});
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group renamed.')));
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Leave Group'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Leave Group'),
                      content: const Text('Are you sure you want to leave this group?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Leave'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // Remove user from group
                    final memberToRemove = group.members.firstWhere((m) => m.userId == userId);
                    await FirebaseFirestore.instance.collection('groups').doc(group.id).update({
                      'members': FieldValue.arrayRemove([memberToRemove.toMap()]),
                    });
                    await FirebaseFirestore.instance.collection('users').doc(userId).update({
                      'groupIds': FieldValue.arrayRemove([group.id]),
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You left the group.')));
                  }
                },
              ),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Group'),
                        content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await groupProvider.deleteGroup(group.id, userId);
                        Navigator.of(context).pop();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete group: $e')));
                      }
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export Expenses'),
                onTap: () async {
                  Navigator.pop(context);
                  final format = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Export Expenses'),
                      content: const Text('Choose export format:'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'csv'),
                          child: const Text('CSV'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'pdf'),
                          child: const Text('PDF'),
                        ),
                      ],
                    ),
                  );
                  if (format == null) return;
                  try {
                    // Fetch expenses
                    final expensesSnapshot = await FirebaseFirestore.instance
                        .collection('groups')
                        .doc(group.id)
                        .collection('expenses')
                        .orderBy('timestamp', descending: false)
                        .get();
                    // Fetch user info for paidBy
                    final userIds = expensesSnapshot.docs.map((doc) => doc['paidBy'] as String?).whereType<String>().toSet().toList();
                    final usersSnapshot = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: userIds).get();
                    final userMap = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['username'] ?? doc.id};
                    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
                    List<List<dynamic>> rows = [
                      ['Date', 'Title/Description', 'Amount', 'Paid By', 'Split Type', 'Notes'],
                    ];
                    for (var doc in expensesSnapshot.docs) {
                      final data = doc.data();
                      DateTime? dateObj;
                      if (data['expenseDate'] != null) {
                        dateObj = (data['expenseDate'] as Timestamp).toDate();
                      } else if (data['timestamp'] != null) {
                        dateObj = (data['timestamp'] as Timestamp).toDate();
                      }
                      final date = dateObj != null ? dateFormat.format(dateObj) : '';
                      final paidByName = userMap[data['paidBy']] ?? data['paidBy'] ?? '';
                      rows.add([
                        date,
                        data['description'] ?? data['title'] ?? '',
                        data['amount'] ?? '',
                        paidByName,
                        data['splitType'] ?? '',
                        data['notes'] ?? '',
                      ]);
                    }
                    if (format == 'csv') {
                      String csvData = const ListToCsvConverter().convert(rows);
                      final dir = await getTemporaryDirectory();
                      final file = File('${dir.path}/${group.name}_expenses.csv');
                      await file.writeAsString(csvData);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Expenses exported to ${file.path}')),
                      );
                    } else if (format == 'pdf') {
                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.Page(
                          build: (pw.Context context) => pw.Table.fromTextArray(
                            data: rows,
                            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            cellAlignment: pw.Alignment.centerLeft,
                          ),
                        ),
                      );
                      final dir = await getTemporaryDirectory();
                      final file = File('${dir.path}/${group.name}_expenses.pdf');
                      await file.writeAsBytes(await pdf.save());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Expenses exported to ${file.path}')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to export: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
