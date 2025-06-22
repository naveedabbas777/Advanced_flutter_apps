import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class InvitationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Invitations'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('group_invitations')
            .where('invitedUserId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Error loading invitations:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Optionally, trigger a reload
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No pending invitations.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You currently have no new group invitations.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.home),
                    label: Text('Back to Home'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var invitation = snapshot.data!.docs[index];
              var invitationData = invitation.data() as Map<String, dynamic>;
              String invitationId = invitation.id;
              String groupId = invitationData['groupId'] ?? '';
              String groupName = invitationData['groupName'] ?? 'Unnamed Group';
              String invitedByUsername = invitationData['invitedByUsername'] ?? '';
              String invitedByEmail = invitationData['invitedByEmail'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invitation to Join: ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.normal),
                      ),
                      Text(
                        groupName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (invitedByUsername.isNotEmpty)
                        Text(
                          'Invited by: $invitedByUsername${invitedByEmail.isNotEmpty ? ' ($invitedByEmail)' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        Text(
                          'Invited by: Unknown User',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await context.read<GroupProvider>().acceptInvitation(
                                      invitationId: invitationId,
                                      groupId: groupId,
                                      user: authProvider.currentUserModel!,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Invitation accepted!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await context.read<GroupProvider>().rejectInvitation(
                                      invitationId: invitationId,
                                      groupId: groupId,
                                      userId: user.uid,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Invitation rejected.')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 