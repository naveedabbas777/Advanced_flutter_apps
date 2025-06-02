import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class StudentMessagesScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentMessagesScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentMessagesScreen> createState() => _StudentMessagesScreenState();
}

class _StudentMessagesScreenState extends State<StudentMessagesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  void initState() {
    super.initState();
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    List<Map<String, dynamic>> users = [];

    // Fetch teachers
    final teachersSnapshot = await _firestore.collection('teachers').get();
    users.addAll(teachersSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'] ?? 'Unknown Teacher',
          'type': 'teacher',
        }));

    // Fetch students (excluding the current student)
    final studentsSnapshot = await _firestore.collection('students').get();
    users.addAll(studentsSnapshot.docs
        .where((doc) => doc.id != widget.studentId)
        .map((doc) => {
              'id': doc.id,
              'name': doc['name'] ?? 'Unknown Student',
              'type': 'student',
            }));
    return users;
  }

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Message',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }
                    final users = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple[100],
                            child: Text(
                              (user['name'] as String)[0].toUpperCase(),
                              style: const TextStyle(color: Colors.deepPurple),
                            ),
                          ),
                          title: Text(user['name'] as String),
                          subtitle: Text(user['type'] as String),
                          onTap: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  currentUserId: widget.studentId,
                                  currentUserName: widget.studentName,
                                  currentUserType: 'student',
                                  otherUserId: user['id'] as String,
                                  otherUserName: user['name'] as String,
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
        ),
      ),
    );
  }

  bool _isMessageNewer(Map<String, dynamic> newMessage, Map<String, dynamic> currentLatestMessage) {
    final newTimestamp = newMessage['timestamp'] as Timestamp?;
    final currentTimestamp = currentLatestMessage['timestamp'] as Timestamp?;

    if (newTimestamp == null) return false; // A message without a timestamp is not newer
    if (currentTimestamp == null) return true; // A message with a timestamp is newer than one without

    return newTimestamp.compareTo(currentTimestamp) > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Messages'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('senderId', isEqualTo: widget.studentId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMessages = snapshot.data!.docs;

                // Group messages by conversation partner
                Map<String, Map<String, dynamic>> conversations = {};

                for (var doc in allMessages) {
                  final data = doc.data() as Map<String, dynamic>;
                  String otherUserId;
                  String otherUserName;

                  if (data['senderId'] == widget.studentId) {
                    otherUserId = data['recipientId'] as String;
                    otherUserName = data['recipientName'] as String;
                  } else {
                    otherUserId = data['senderId'] as String;
                    otherUserName = data['senderName'] as String;
                  }

                  // Ensure we get the latest message for each conversation
                  // Also ensure that the other user ID is not null or empty
                  if (otherUserId.isNotEmpty && (!conversations.containsKey(otherUserId) ||
                      _isMessageNewer(data, conversations[otherUserId]!['latestMessage']))) {
                    conversations[otherUserId] = {
                      'otherUserId': otherUserId,
                      'otherUserName': otherUserName,
                      'latestMessage': data,
                    };
                  }
                }

                final conversationList = conversations.values.toList();

                // Sort conversations by the timestamp of their latest message (latest first)
                conversationList.sort((a, b) {
                  final timestampA = a['latestMessage']['timestamp'] as Timestamp?;
                  final timestampB = b['latestMessage']['timestamp'] as Timestamp?;

                  if (timestampA == null && timestampB == null) return 0;
                  if (timestampA == null) return 1;
                  if (timestampB == null) return -1;

                  return timestampB.compareTo(timestampA);
                });

                if (conversationList.isEmpty) {
                  return const Center(child: Text('No conversations yet.'));
                }

                return ListView.builder(
                  itemCount: conversationList.length,
                  itemBuilder: (context, index) {
                    final conversation = conversationList[index];
                    final latestMessage = conversation['latestMessage'];
                    final timestamp = latestMessage['timestamp'] as Timestamp?;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple[100],
                        child: Text(
                          (conversation['otherUserName'] as String)[0].toUpperCase(),
                          style: const TextStyle(color: Colors.deepPurple),
                        ),
                      ),
                      title: Text(conversation['otherUserName'] as String),
                      subtitle: Text(
                        latestMessage['content'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: timestamp != null
                          ? Text(
                              DateFormat.jm().format(timestamp.toDate()),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              currentUserId: widget.studentId,
                              currentUserName: widget.studentName,
                              currentUserType: 'student',
                              otherUserId: conversation['otherUserId'] as String,
                              otherUserName: conversation['otherUserName'] as String,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageDialog(context),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add_comment),
      ),
    );
  }
} 