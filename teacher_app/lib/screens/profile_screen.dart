import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const ProfileScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Stream<DocumentSnapshot> _teacherStream;
  late Stream<QuerySnapshot> _studentsStream;
  late Stream<QuerySnapshot> _tasksStream;
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _teacherStream = FirebaseFirestore.instance
        .collection('teachers')
        .doc(widget.teacherId)
        .snapshots();
    
    _studentsStream = FirebaseFirestore.instance
        .collection('students')
        .where('status', isEqualTo: 'active')
        .snapshots();
    
    _tasksStream = FirebaseFirestore.instance
        .collection('tasks')
        .snapshots();

    _messagesStream = FirebaseFirestore.instance
        .collection('messages')
        .where('teacherId', isEqualTo: widget.teacherId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _teacherStream,
        builder: (context, teacherSnapshot) {
          if (teacherSnapshot.hasError) {
            return Center(child: Text('Error: ${teacherSnapshot.error}'));
          }

          if (!teacherSnapshot.hasData || !teacherSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final teacherData = teacherSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final email = teacherData['email'] as String? ?? 'No email provided';
          final joinDate = teacherData['joinedDate'] != null 
              ? (teacherData['joinedDate'] as Timestamp).toDate()
              : DateTime.now();

          return StreamBuilder<QuerySnapshot>(
            stream: _studentsStream,
            builder: (context, studentsSnapshot) {
              if (studentsSnapshot.hasError) {
                return Center(child: Text('Error: ${studentsSnapshot.error}'));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _tasksStream,
                builder: (context, tasksSnapshot) {
                  if (tasksSnapshot.hasError) {
                    return Center(child: Text('Error: ${tasksSnapshot.error}'));
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
                    builder: (context, messagesSnapshot) {
                      if (messagesSnapshot.hasError) {
                        return Center(child: Text('Error: ${messagesSnapshot.error}'));
                      }

                      // Calculate statistics with null safety
                      final totalStudents = studentsSnapshot.hasData ? studentsSnapshot.data!.docs.length : 0;
                      final totalTasks = tasksSnapshot.hasData ? tasksSnapshot.data!.docs.length : 0;
                      
                      // Calculate completed tasks with null safety
                      final completedTasks = tasksSnapshot.hasData 
                          ? tasksSnapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>? ?? {};
                              return data['status'] == 'completed';
                            }).length
                          : 0;

                      // Calculate message statistics with null safety
                      final totalMessages = messagesSnapshot.hasData ? messagesSnapshot.data!.docs.length : 0;
                      final unreadMessages = messagesSnapshot.hasData 
                          ? messagesSnapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>? ?? {};
                              return data['status'] == 'unread' && data['recipientId'] == widget.teacherId;
                            }).length
                          : 0;

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            // Profile Card
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 10,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.deepPurple[100],
                                    child: Text(
                                      widget.teacherName.isNotEmpty 
                                          ? widget.teacherName[0].toUpperCase()
                                          : 'T',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.teacherName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple[50],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Teacher',
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.email, size: 20, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Joined ${DateFormat('dd/MM/yyyy').format(joinDate)}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Statistics Card
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 10,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Statistics',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildStatRow(
                                    Icons.people,
                                    'Active Students',
                                    totalStudents.toString(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStatRow(
                                    Icons.assignment,
                                    'Total Tasks',
                                    totalTasks.toString(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStatRow(
                                    Icons.check_circle,
                                    'Completed Tasks',
                                    completedTasks.toString(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStatRow(
                                    Icons.pending_actions,
                                    'Pending Tasks',
                                    (totalTasks - completedTasks).toString(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStatRow(
                                    Icons.message,
                                    'Total Messages',
                                    totalMessages.toString(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStatRow(
                                    Icons.mark_email_unread,
                                    'Unread Messages',
                                    unreadMessages.toString(),
                                    color: unreadMessages > 0 ? Colors.red : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color ?? Colors.grey),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: color ?? Colors.grey,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
} 