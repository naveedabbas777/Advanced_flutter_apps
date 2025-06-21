import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/group_provider.dart';
import 'package:split_app/models/group_model.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_details_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Split App'),
        actions: [
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Your Groups',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
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

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    String groupId = group.id;
                    String groupName = group.name;

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16.0),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Text(
                            groupName.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
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
                                        Text('Total: 	${totalSpent.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
                                        SizedBox(width: 12),
                                        Icon(Icons.group, size: 16, color: Theme.of(context).colorScheme.primary),
                                        SizedBox(width: 4),
                                        Text('Members: ${group.members.length}', style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Your Balance: 	${balance.toStringAsFixed(2)}',
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
                        trailing: Icon(Icons.arrow_forward_ios),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => CreateGroupScreen()));
        },
        icon: Icon(Icons.add),
        label: Text('Create Group'),
      ),
    );
  }
} 