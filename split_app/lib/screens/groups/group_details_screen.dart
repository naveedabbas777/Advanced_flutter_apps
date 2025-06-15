import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../services/group_service.dart';
// import '../../services/expense_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import 'package:split_app/screens/expenses/add_expense_screen.dart';
import 'package:split_app/screens/members/add_member_screen.dart';

// Re-applying to refresh parsing due to persistent 'Expected an identifier' error.
class GroupDetailsScreen extends StatelessWidget {
  final String groupId;

  GroupDetailsScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    return StreamBuilder<DocumentSnapshot>(
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

        var groupData = snapshot.data!.data() as Map<String, dynamic>;
        String groupName = groupData['name'] ?? 'No Name';
        List<String> members = List<String>.from(groupData['members'] ?? []);

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
                          children: members.map((memberId) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(memberId)
                                  .get(),
                              builder: (context, userSnapshot) {
                                if (userSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Chip(label: Text('Loading...'));
                                }
                                if (userSnapshot.hasError ||
                                    !userSnapshot.hasData ||
                                    !userSnapshot.data!.exists) {
                                  return const Chip(label: Text('Unknown'));
                                }
                                var userData = userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                String memberName = userData['name'] ??
                                    userData['email'] ??
                                    'Unknown';
                                return Chip(
                                  label: Text(memberName),
                                  avatar: CircleAvatar(
                                      child: Text(memberName
                                          .substring(0, 1)
                                          .toUpperCase())),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withOpacity(0.1),
                                );
                              },
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

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: expenseSnapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var expense = expenseSnapshot.data!.docs[index];
                        var expenseData =
                            expense.data() as Map<String, dynamic>;

                        String description =
                            expenseData['description'] ?? 'No Description';
                        double amount =
                            (expenseData['amount'] as num).toDouble();
                        String paidByUserId = expenseData['paidBy'] ?? '';
                        Timestamp timestamp =
                            expenseData['timestamp'] ?? Timestamp.now();

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(paidByUserId)
                              .get(),
                          builder: (context, userPaidBySnapshot) {
                            String paidByName = 'Unknown';
                            if (userPaidBySnapshot.hasData &&
                                userPaidBySnapshot.data!.exists) {
                              paidByName = userPaidBySnapshot.data!['name'] ??
                                  userPaidBySnapshot.data!['email'] ??
                                  'Unknown';
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16.0),
                                title: Text(
                                  description,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Paid by: $paidByName',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${timestamp.toDate().toLocal().toString().split(' ')[0]}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '${amount.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
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
