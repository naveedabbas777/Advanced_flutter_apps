import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class NotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppAuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          // Invitations
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Invitations', style: Theme.of(context).textTheme.titleMedium),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('group_invitations')
                .where('invitedUserId', isEqualTo: user.uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading invitations: \\${snapshot.error}', style: TextStyle(color: Colors.red)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No pending invitations.'),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.mail_outline),
                      title: Text('Group: \\${data['groupName'] ?? 'Unnamed Group'}'),
                      subtitle: Text('Invited by: \\${data['invitedByUsername'] ?? 'Unknown'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Optionally navigate to group or invitation details
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // Group Join/Leave Events
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Group Events', style: Theme.of(context).textTheme.titleMedium),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('group_events')
                .where('userId', isEqualTo: user.uid)
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading group events: \\${snapshot.error}', style: TextStyle(color: Colors.red)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No group events.'),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.group),
                      title: Text(data['eventType'] ?? 'Event'),
                      subtitle: Text(data['description'] ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // Expense Updates
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Expense Updates', style: Theme.of(context).textTheme.titleMedium),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('expense_notifications')
                .where('userId', isEqualTo: user.uid)
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading expense updates: \\${snapshot.error}', style: TextStyle(color: Colors.red)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No expense updates.'),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.attach_money),
                      title: Text(data['title'] ?? 'Expense Update'),
                      subtitle: Text(data['description'] ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // Expense Add/Edit Notifications
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Group Expense Notifications', style: Theme.of(context).textTheme.titleMedium),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('group_expense_notifications')
                .where('userId', isEqualTo: user.uid)
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading group expense notifications: \\${snapshot.error}', style: TextStyle(color: Colors.red)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No group expense notifications.'),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final action = data['action'] ?? 'updated';
                  final groupName = data['groupName'] ?? 'Group';
                  final expenseTitle = data['expenseTitle'] ?? 'Expense';
                  final amount = data['amount'] != null ? 'Amount: \\${data['amount']}' : '';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Icon(action == 'added' ? Icons.add : Icons.edit, color: action == 'added' ? Colors.green : Colors.orange),
                      title: Text('$groupName: $expenseTitle'),
                      subtitle: Text('${action == 'added' ? 'Added' : 'Edited'} $amount'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
} 