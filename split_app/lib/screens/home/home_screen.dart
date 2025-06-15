import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_details_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .where('members', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var group = snapshot.data!.docs[index];
                    var groupData = group.data() as Map<String, dynamic>;
                    String groupId = group.id;
                    String groupName = groupData['name'] ?? 'No Name';

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
                        subtitle: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('groups')
                              .doc(groupId)
                              .collection('expenses')
                              .snapshots(),
                          builder: (context, expenseSnapshot) {
                            if (expenseSnapshot.hasError) {
                              return Text('Error loading expenses', style: TextStyle(color: Colors.red));
                            }
                            if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                              return Text('Loading balance...');
                            }

                            double totalSpent = 0.0;
                            double userShare = 0.0;
                            double userOwes = 0.0;
                            double userIsOwed = 0.0;

                            final expenses = expenseSnapshot.data!.docs;
                            final members = List<String>.from(groupData['members'] ?? []);
                            final numMembers = members.length;

                            for (var expenseDoc in expenses) {
                              var expenseData = expenseDoc.data() as Map<String, dynamic>;
                              double amount = (expenseData['amount'] as num).toDouble();
                              String paidBy = expenseData['paidBy'];

                              totalSpent += amount;
                              double individualShare = amount / numMembers;

                              if (paidBy == user.uid) {
                                userIsOwed += (amount - individualShare);
                              } else if (members.contains(user.uid)) {
                                // User is a member but didn't pay
                                userOwes += individualShare;
                              }
                            }

                            double balance = userIsOwed - userOwes;
                            Color balanceColor = balance == 0
                                ? Colors.grey
                                : (balance > 0 ? Colors.green : Colors.red);

                            return Text(
                              'Balance: \${balance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: balanceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
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