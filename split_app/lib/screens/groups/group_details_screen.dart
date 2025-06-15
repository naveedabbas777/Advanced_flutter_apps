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
    final groupProvider = Provider.of<GroupProvider>(context); // Access GroupProvider
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
              if (groupProvider.isUserAdmin(user.uid, group.members)) ...[
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
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Group'),
                        content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              try {
                                await groupProvider.deleteGroup(groupId, user.uid);
                                Navigator.pop(context); // Return to previous screen
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          body: Column(
            children: [
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
                            return Chip(
                              label: Text(member.username),
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
                                              groupId: groupId,
                                              userId: member.userId,
                                              removedBy: user.uid,
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(e.toString())),
                                            );
                                          }
                                        } : null,
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
                        .doc(groupId)
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
                                      Text(member.username, style: Theme.of(context).textTheme.bodyMedium),
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
                            expenseData['timestamp'] as Timestamp? ?? Timestamp.now();

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
                                      'Split: $splitInfo',
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
