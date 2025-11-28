import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
// import '../../services/group_service.dart';
// import '../../services/expense_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import 'package:split_app/models/group_model.dart';
import 'group_chat_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_app/screens/groups/user_invite_search_screen.dart';
import 'package:split_app/screens/groups/group_summary_screen.dart';
import 'package:split_app/screens/groups/settle_up_screen.dart';
import 'package:split_app/screens/groups/group_members_screen.dart';
import 'package:split_app/screens/groups/group_summary_table_screen.dart';
import 'package:split_app/screens/expenses/add_expense_screen.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../services/notification_listener_service.dart';
import '../../services/badge_service.dart';

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
  bool _showAllExpenses = false;
  StreamSubscription? _badgeSub;
  @override
  void initState() {
    super.initState();
    _markExpensesAsSeen();
    // Start notification & badge tracking for current user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      NotificationListenerService().startListening(user.uid);
      // Start badge tracking in background (non-blocking)
      BadgeService().startTracking(user.uid);
    }
  }

  @override
  void dispose() {
    // Stop background listeners when leaving screen
    NotificationListenerService().stopListening();
    BadgeService().stopTracking();
    _badgeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...existing code before expenses history...
    return Consumer2<GroupProvider, AppAuthProvider>(
      builder: (context, groupProvider, authProvider, _) {
        // ...existing code to get group, userId, isAdmin, etc...
        // Find the correct place in your UI to insert the expenses history widget:
        // For example, after group details and before the floating action button.
        return Scaffold(
          backgroundColor: const Color(0xFFFAF5FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFF6A1B9A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists)
                  return const Text('Group',
                      style: TextStyle(color: Colors.white));
                final g = GroupModel.fromFirestore(snap.data!);
                return Text(g.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600));
              },
            ),
            centerTitle: true,
            elevation: 0,
            actions: [
              // Summary (open graph summary)
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () async {
                  final doc = await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .get();
                  if (!doc.exists) return;
                  final group = GroupModel.fromFirestore(doc);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GroupSummaryScreen(
                      groupId: widget.groupId,
                      members: group.members,
                      groupName: group.name,
                    ),
                  ));
                },
              ),
              // Invite / Members badge
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .snapshots(),
                builder: (context, snap) {
                  final group = (snap.hasData && snap.data!.exists)
                      ? GroupModel.fromFirestore(snap.data!)
                      : null;
                  final count = group?.members.length ?? 0;
                  return IconButton(
                    icon: badges.Badge(
                      badgeContent: Text(count.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                      showBadge: count > 0,
                      child: const Icon(Icons.person_add, color: Colors.white),
                    ),
                    onPressed: () async {
                      if (group == null) return;
                      final currentUserId =
                          FirebaseAuth.instance.currentUser?.uid ?? '';
                      final memberIds =
                          group.members.map((m) => m.userId).toList();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UserInviteSearchScreen(
                          groupId: widget.groupId,
                          currentMemberIds: memberIds,
                          currentUserId: currentUserId,
                        ),
                      ));
                    },
                  );
                },
              ),
              // Settle Up
              IconButton(
                icon: const Icon(Icons.payments_outlined),
                onPressed: () async {
                  final doc = await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .get();
                  if (!doc.exists) return;
                  final group = GroupModel.fromFirestore(doc);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettleUpScreen(
                        groupId: widget.groupId,
                        groupName: group.name,
                        members: group.members),
                  ));
                },
              ),
              // Chat
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () async {
                  final doc = await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .get();
                  if (!doc.exists) return;
                  final group = GroupModel.fromFirestore(doc);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GroupChatScreen(
                        groupId: widget.groupId, groupName: group.name),
                  ));
                },
              ),
              // Settings
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  final doc = await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .get();
                  if (!doc.exists) return;
                  final group = GroupModel.fromFirestore(doc);
                  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
                  final isAdmin =
                      group.members.any((m) => m.userId == userId && m.isAdmin);
                  _showGroupSettings(context, group, isAdmin, userId,
                      Provider.of<GroupProvider>(context, listen: false));
                },
              ),
            ],
          ),
          // ...other properties...
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group header (avatar, info cards, members/summary links)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .snapshots(),
                  builder: (context, groupSnap) {
                    if (!groupSnap.hasData || !groupSnap.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    final group = GroupModel.fromFirestore(groupSnap.data!);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Center(
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: Text(
                                group.name.isNotEmpty
                                    ? group.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(group.name,
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.black54),
                                const SizedBox(width: 8),
                                Expanded(
                                    child:
                                        Text(group.description ?? group.name)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    color: Colors.black54),
                                const SizedBox(width: 8),
                                Text(
                                    'Initial: \$${group.initialAmount?.toStringAsFixed(2) ?? '0.00'}',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.people_outline),
                              title: Text('Members (${group.members.length})'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => GroupMembersScreen(
                                    groupId: widget.groupId,
                                    groupName: group.name,
                                    members: group.members,
                                  ),
                                ));
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.table_chart),
                              title: const Text('Summary Table'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => GroupSummaryTableScreen(
                                    groupId: widget.groupId,
                                    groupName: group.name,
                                    members: group.members,
                                    initialAmount: group.initialAmount,
                                    createdBy: group.createdBy,
                                  ),
                                ));
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Expenses History',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('expenses')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final docs = snap.data!.docs;
                    final total = docs.length;
                    const previewCount = 5;
                    final displayCount = _showAllExpenses
                        ? total
                        : (total < previewCount ? total : previewCount);

                    if (total == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Text('No expenses yet',
                            style: Theme.of(context).textTheme.bodyMedium),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListView.builder(
                            itemCount: displayCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final title = data['title'] ??
                                  data['description'] ??
                                  'Expense';
                              final amount = (data['amount'] is num)
                                  ? (data['amount'] as num).toDouble()
                                  : double.tryParse('${data['amount']}') ?? 0.0;
                              final paidBy = data['paidBy'] ?? '';
                              final timestamp = data['timestamp'] is Timestamp
                                  ? (data['timestamp'] as Timestamp).toDate()
                                  : null;
                              final dateStr = timestamp != null
                                  ? DateFormat.yMMMd()
                                      .add_jm()
                                      .format(timestamp)
                                  : '';

                              return Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  title: Text(title),
                                  subtitle: Text(
                                      '${paidBy.toString()}${dateStr.isNotEmpty ? ' • $dateStr' : ''}'),
                                  trailing: Text(
                                      '\$${amount.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ),
                              );
                            },
                          ),
                          if (total > previewCount)
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: () => setState(
                                    () => _showAllExpenses = !_showAllExpenses),
                                child: Text(_showAllExpenses
                                    ? 'Show Less'
                                    : 'Show All ($total)'),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                // ...other widgets...
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .get();
              if (!doc.exists) return;
              final group = GroupModel.fromFirestore(doc);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddExpenseScreen(
                    groupId: widget.groupId, groupName: group.name),
              ));
            },
            label: const Text('+ Add Expense'),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }
// Removed duplicate/old widget tree. Only one build method remains above with expenses history in place.

  void _showGroupSettings(BuildContext context, GroupModel group, bool isAdmin,
      String userId, GroupProvider groupProvider) {
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
                        final controller =
                            TextEditingController(text: group.name);
                        return AlertDialog(
                          title: const Text('Rename Group'),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                                labelText: 'New group name'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(
                                  context, controller.text.trim()),
                              child: const Text('Rename'),
                            ),
                          ],
                        );
                      },
                    );
                    if (newName != null &&
                        newName.isNotEmpty &&
                        newName != group.name) {
                      await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(group.id)
                          .update({'name': newName});
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Group renamed.')));
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
                      content: const Text(
                          'Are you sure you want to leave this group?'),
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
                    try {
                      final memberToRemove =
                          group.members.firstWhere((m) => m.userId == userId);
                      print('Attempting to remove member:');
                      print(memberToRemove.toMap());
                      await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(group.id)
                          .update({
                        'members':
                            FieldValue.arrayRemove([memberToRemove.toMap()]),
                        'memberIds': FieldValue.arrayRemove([userId]),
                      });
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .update({
                        'groupIds': FieldValue.arrayRemove([group.id]),
                      });

                      // Refresh notification listeners
                      final authProvider =
                          Provider.of<AppAuthProvider>(context, listen: false);
                      if (authProvider.currentUser != null) {
                        await NotificationListenerService().refreshUserGroups();
                      }

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You left the group.')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to leave group: $e')));
                    }
                  }
                },
              ),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Group',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Group'),
                        content: const Text(
                            'Are you sure you want to delete this group? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await groupProvider.deleteGroup(group.id, userId);
                        Navigator.of(context).pop();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Failed to delete group: $e')));
                      }
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export Expenses'),
                onTap: () async {
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
                  if (format == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('No export format selected.')),
                    );
                    return;
                  }
                  try {
                    final expensesSnapshot = await FirebaseFirestore.instance
                        .collection('groups')
                        .doc(group.id)
                        .collection('expenses')
                        .orderBy('timestamp', descending: false)
                        .get();

                    if (expensesSnapshot.docs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No expenses to export.')),
                      );
                      return;
                    }

                    // Get all group members for split columns
                    final groupMembers = group.members;

                    // Get user info for paidBy
                    final userIds = expensesSnapshot.docs
                        .map((doc) => doc['paidBy'] as String?)
                        .whereType<String>()
                        .toSet()
                        .toList();
                    final usersSnapshot = await FirebaseFirestore.instance
                        .collection('users')
                        .where(FieldPath.documentId, whereIn: userIds)
                        .get();
                    final userMap = {
                      for (var doc in usersSnapshot.docs)
                        doc.id: doc.data()['username'] ?? doc.id
                    };
                    final userEmailMap = {
                      for (var doc in usersSnapshot.docs)
                        doc.id: doc.data()['email'] ?? ''
                    };

                    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
                    // Header: add a column for each member's share
                    List<String> header = [
                      'Date',
                      'Title/Description',
                      'Amount',
                      'Paid By',
                      'Paid By Email',
                      'Split Type',
                      ...groupMembers.map((m) => 'Share: ${m.username}'),
                      'Notes',
                      'Category'
                    ];
                    List<List<dynamic>> rows = [header];

                    for (var doc in expensesSnapshot.docs) {
                      final data = doc.data();
                      DateTime? dateObj;
                      if (data['expenseDate'] != null) {
                        if (data['expenseDate'] is Timestamp) {
                          dateObj = (data['expenseDate'] as Timestamp).toDate();
                        } else if (data['expenseDate'] is String) {
                          dateObj = DateTime.tryParse(data['expenseDate']);
                        }
                      }
                      if (dateObj == null && data['timestamp'] != null) {
                        if (data['timestamp'] is Timestamp) {
                          dateObj = (data['timestamp'] as Timestamp).toDate();
                        } else if (data['timestamp'] is String) {
                          dateObj = DateTime.tryParse(data['timestamp']);
                        }
                      }
                      // Always format as a string for export
                      final date =
                          dateObj != null ? dateFormat.format(dateObj) : '';
                      final paidById = data['paidBy'];
                      final paidByName = userMap[paidById] ?? paidById ?? '';
                      final paidByEmail = userEmailMap[paidById] ?? '';
                      final splitType = data['splitType'] ?? '';
                      final notes = data['notes'] ?? '';
                      final category = data['category'] ?? '';
                      final amount = data['amount'] ?? '';
                      final description =
                          data['description'] ?? data['title'] ?? '';

                      // Prepare shares for each member
                      List<String> shares = [];
                      if (splitType == 'custom' && data['splitData'] is Map) {
                        final splitData =
                            data['splitData'] as Map<String, dynamic>;
                        for (var m in groupMembers) {
                          final share = splitData[m.userId];
                          shares.add(share != null ? share.toString() : '');
                        }
                      } else if (splitType == 'equal' &&
                          data['splitAmong'] is List) {
                        // Equal split: divide amount equally among splitAmong
                        final splitAmong =
                            List<String>.from(data['splitAmong'] ?? []);
                        final perMember =
                            (amount is num && splitAmong.isNotEmpty)
                                ? (amount / splitAmong.length)
                                : '';
                        for (var m in groupMembers) {
                          shares.add(splitAmong.contains(m.userId)
                              ? perMember.toString()
                              : '');
                        }
                      } else {
                        // Fallback: leave shares blank
                        for (var _ in groupMembers) {
                          shares.add('');
                        }
                      }

                      rows.add([
                        date,
                        description,
                        amount,
                        paidByName,
                        paidByEmail,
                        splitType,
                        ...shares,
                        notes,
                        category
                      ]);
                    }

                    final dir = await getTemporaryDirectory();
                    if (format == 'csv') {
                      String csvData = const ListToCsvConverter().convert(rows);
                      final file =
                          File('${dir.path}/${group.name}_expenses.csv');
                      await file.writeAsString(csvData);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Expenses exported to ${file.path}')),
                      );
                      await Share.shareXFiles([
                        XFile(file.path,
                            mimeType: 'text/csv',
                            name: '${group.name}_expenses.csv'),
                      ], subject: 'Exported Expenses CSV');
                    } else if (format == 'pdf') {
                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.Page(
                          build: (pw.Context context) => pw.Table.fromTextArray(
                            data: rows,
                            headerStyle:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            cellAlignment: pw.Alignment.centerLeft,
                          ),
                        ),
                      );
                      final file =
                          File('${dir.path}/${group.name}_expenses.pdf');
                      await file.writeAsBytes(await pdf.save());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Expenses exported to ${file.path}')),
                      );
                      await Share.shareXFiles([
                        XFile(file.path,
                            mimeType: 'application/pdf',
                            name: '${group.name}_expenses.pdf'),
                      ], subject: 'Exported Expenses PDF');
                    }
                    Navigator.pop(context);
                  } catch (e, stack) {
                    print('Export error: $e\n$stack');
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

// Placeholder method to mark expenses as seen.
// Implement specific Firestore update logic here if desired.
void _markExpensesAsSeen() {
  // No-op for now to avoid undefined method error.
}
