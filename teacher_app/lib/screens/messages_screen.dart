import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  final String userId;
  final String userType;
  final String userName;

  const MessagesScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.userName,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and New Message Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: () => _showNewMessageDialog(context),
                  backgroundColor: Colors.deepPurple,
                  child: const Icon(Icons.edit),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('senderId', isEqualTo: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet'),
                  );
                }

                // Create a map of unique conversations
                final conversations = <String, Map<String, dynamic>>{};
                for (var doc in messages) {
                  final data = doc.data() as Map<String, dynamic>;
                  final recipientId = data['recipientId'] as String;
                  
                  if (!conversations.containsKey(recipientId)) {
                    conversations[recipientId] = {
                      'userId': recipientId,
                      'name': data['recipientName'],
                      'lastMessage': data['content'],
                      'timestamp': data['timestamp'],
                    };
                  }
                }

                final conversationsList = conversations.values.toList();

                return ListView.builder(
                  itemCount: conversationsList.length,
                  itemBuilder: (context, index) {
                    final conversation = conversationsList[index];
                    final timestamp = conversation['timestamp'] as Timestamp?;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple[100],
                        child: Text(
                          (conversation['name'] as String)[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        conversation['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        conversation['lastMessage'] as String,
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
                              currentUserId: widget.userId,
                              currentUserName: widget.userName,
                              currentUserType: widget.userType,
                              otherUserId: conversation['userId'] as String,
                              otherUserName: conversation['name'] as String,
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
    );
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
              SizedBox(
                height: 300, // Fixed height for the list
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('students').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final students = snapshot.data!.docs;

                    if (students.isEmpty) {
                      return const Center(child: Text('No students found'));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final studentDoc = students[index];
                        final studentData = studentDoc.data() as Map<String, dynamic>;
                        final studentName = studentData['name'] as String? ?? 'Unknown';
                        final studentId = studentDoc.id;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple[100],
                            child: Text(
                              studentName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.deepPurple),
                            ),
                          ),
                          title: Text(studentName),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  currentUserId: widget.userId,
                                  currentUserName: widget.userName,
                                  currentUserType: widget.userType,
                                  otherUserId: studentId,
                                  otherUserName: studentName,
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
} 