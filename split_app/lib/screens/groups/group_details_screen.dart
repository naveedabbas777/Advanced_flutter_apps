import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/group_service.dart';
import '../../services/expense_service.dart';
import 'add_expense_screen.dart';
import 'add_member_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class GroupDetailsScreen extends StatelessWidget {
  final String groupId;

  const GroupDetailsScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final groupData = snapshot.data?.data() as Map<String, dynamic>?;
        if (groupData == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text('Group not found'),
            ),
          );
        }

        final groupName = groupData['name'] as String? ?? 'Unnamed Group';

        return Scaffold(
          appBar: AppBar(
            title: Text(groupName),
            actions: [
              IconButton(
                icon: Icon(Icons.person_add),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/add-member',
                    arguments: groupId,
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('expenses')
                      .where('groupId', isEqualTo: groupId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final expenses = snapshot.data?.docs ?? [];

                    if (expenses.isEmpty) {
                      return Center(
                        child: Text('No expenses yet'),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            title: Text(expense['description'] ?? 'No description'),
                            subtitle: Text(
                              'Amount: ${expense['amount']?.toString() ?? '0'}',
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: Show expense details
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
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/add-expense',
                arguments: {
                  'groupId': groupId,
                  'groupName': groupName,
                },
              );
            },
            child: Icon(Icons.add),
          ),
        );
      },
    );
  }
} 