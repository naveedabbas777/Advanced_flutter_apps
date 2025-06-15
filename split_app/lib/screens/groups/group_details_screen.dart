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

// Re-applying to refresh parsing due to persistent 'Expected an identifier' error.
class GroupDetailsScreen extends StatelessWidget {
  final String groupId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
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
            body: const Center(child: Text('Group not found.')),
          );
        }

        final group = GroupModel.fromFirestore(snapshot.data!);

        String groupName = group.name;
        List<GroupMember> groupMembers = group.members;

        return Scaffold(
          appBar: AppBar(
            title: Text(groupName),
            actions: [
              IconButton(
                icon: const Icon(Icons.group_add),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/add-member',
                    arguments: {'groupId': groupId},
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
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
                        Text(
                          'Group Members',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          children: groupMembers.map((member) {
                            return Chip(
                              label: Text(member.username),
                              avatar: CircleAvatar(
                                  child: Text(member.username
                                      .substring(0, 1)
                                      .toUpperCase())),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.1),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Expenses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId)
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

                    final expenses = expenseSnapshot.data!.docs;
                    final currentUserUid = user.uid;

                    double totalSpent = 0.0;
                    double userIsOwed = 0.0;
                    double userOwes = 0.0;

                    for (var expenseDoc in expenses) {
                      var expenseData = expenseDoc.data() as Map<String, dynamic>;
                      double amount = (expenseData['amount'] as num?)?.toDouble() ?? 0.0;
                      String paidBy = expenseData['paidBy']?.toString() ?? '';
                      String splitType = expenseData['splitType']?.toString() ?? 'equal';
                      dynamic splitData = expenseData['splitData'];

                      totalSpent += amount;

                      double currentUserShare = 0.0;

                      if (splitType == 'equal') {
                        final numMembers = group.members.length; // Ensure this is from the actual group members list
                        currentUserShare = numMembers > 0 ? amount / numMembers : 0.0;
                      } else if (splitType == 'custom' && splitData is Map<String, dynamic>) {
                        // Ensure customSplitAmounts map is stored with double values
                        currentUserShare = (splitData[currentUserUid] as num?)?.toDouble() ?? 0.0;
                      }

                      if (paidBy == currentUserUid) {
                        // If current user paid, they are owed their share minus what they contributed
                        userIsOwed += (amount - currentUserShare);
                      } else {
                        // If current user is part of the split, they owe their share
                        // Check if user is among those who need to pay (for both equal and custom split)
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
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: expenseSnapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              var expense = expenseSnapshot.data!.docs[index];
                              var expenseData =
                                  expense.data() as Map<String, dynamic>;

                              String description =
                                  expenseData['description']?.toString() ?? 'No Description';
                              double amount =
                                  (expenseData['amount'] as num?)?.toDouble() ?? 0.0;
                              String paidByUserId = expenseData['paidBy']?.toString() ?? '';
                              Timestamp timestamp =
                                  expenseData['timestamp'] as Timestamp? ?? Timestamp.now();

                              String splitType = expenseData['splitType']?.toString() ?? 'equal';
                              dynamic splitData = expenseData['splitData']; // Can be List<String> or Map<String, double>

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
                                    child: ListTile(
                                      title: Text(description),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Paid by: $paidByUsername'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Date: ${timestamp.toDate().toLocal().day}/${timestamp.toDate().toLocal().month}/${timestamp.toDate().toLocal().year}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                          if (expenseData['notes'] != null &&
                                              expenseData['notes'].isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                'Notes: ${expenseData['notes']}',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Split: $splitInfo', // Display split type
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      trailing: Text(
                                        '\$' + amount.toStringAsFixed(2),
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      onTap: () {
                                        // TODO: Navigate to expense details or edit screen
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Balance: \${balance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: balanceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                arguments: {'groupId': groupId, 'groupName': groupName},
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
          ),
        );
      },
    );
  }
}
