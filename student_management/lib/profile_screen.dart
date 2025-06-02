import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Required for StreamController and StreamSubscription

class ProfileScreen extends StatefulWidget {
  final String studentId;
  const ProfileScreen({required this.studentId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _profileDataController = StreamController<Map<String, dynamic>>.broadcast();
  
  StreamSubscription<DocumentSnapshot>? _studentSubscription;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  StreamSubscription<QuerySnapshot>? _sentMessagesSubscription;
  StreamSubscription<QuerySnapshot>? _receivedMessagesSubscription;
  StreamSubscription<QuerySnapshot>? _subjectsSubscription;

  DocumentSnapshot? _latestStudentSnapshot;
  QuerySnapshot? _latestTasksSnapshot;
  QuerySnapshot? _latestSentMessagesSnapshot;
  QuerySnapshot? _latestReceivedMessagesSnapshot;
  QuerySnapshot? _latestSubjectsSnapshot;

  @override
  void initState() {
    super.initState();
    _subscribeToProfileData();
  }

  void _subscribeToProfileData() {
    _studentSubscription = _firestore
        .collection('students')
        .doc(widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _latestStudentSnapshot = snapshot;
      _updateProfileData();
    });

    _tasksSubscription = _firestore
        .collection('tasks')
        .where('assignedTo', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _latestTasksSnapshot = snapshot;
      _updateProfileData();
    });

    _sentMessagesSubscription = _firestore
        .collection('messages')
        .where('senderId', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _latestSentMessagesSnapshot = snapshot;
      _updateProfileData();
    });

    _receivedMessagesSubscription = _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _latestReceivedMessagesSnapshot = snapshot;
      _updateProfileData();
    });

    _subjectsSubscription = _firestore
        .collection('subject_registrations')
        .where('studentId', isEqualTo: widget.studentId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      _latestSubjectsSnapshot = snapshot;
      _updateProfileData();
    });
  }

  void _updateProfileData() {
    if (_latestStudentSnapshot == null || !_latestStudentSnapshot!.exists) {
      _profileDataController.add({}); // No student data, emit empty
      return;
    }

    final studentData = _latestStudentSnapshot!.data() as Map<String, dynamic>;

    // Calculate tasks statistics
    int totalTasks = _latestTasksSnapshot?.docs.length ?? 0;
    int completedTasks = _latestTasksSnapshot?.docs
            .where((doc) => doc['status'] == 'completed')
            .length ??
        0;
    int pendingTasks = totalTasks - completedTasks;

    // Calculate messages statistics
    int totalSentMessages = _latestSentMessagesSnapshot?.docs.length ?? 0;
    int totalReceivedMessages = _latestReceivedMessagesSnapshot?.docs.length ?? 0;
    int totalMessages = totalSentMessages + totalReceivedMessages;
    int unreadMessages = _latestReceivedMessagesSnapshot?.docs
            .where((doc) => doc['status'] == 'sent') // Assuming 'sent' means unread for receiver
            .length ??
        0;

    // Calculate subjects statistics
    int totalSubjects = _latestSubjectsSnapshot?.docs.length ?? 0;

    _profileDataController.add({
      'name': studentData['name'] ?? 'N/A',
      'email': studentData['email'] ?? 'N/A',
      'joinedDate': (studentData['joinedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'pendingTasks': pendingTasks,
      'totalMessages': totalMessages,
      'unreadMessages': unreadMessages,
      'totalSubjects': totalSubjects,
    });
  }

  @override
  void dispose() {
    _studentSubscription?.cancel();
    _tasksSubscription?.cancel();
    _sentMessagesSubscription?.cancel();
    _receivedMessagesSubscription?.cancel();
    _subjectsSubscription?.cancel();
    _profileDataController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _profileDataController.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No profile data found.'));
          }

          final profileData = snapshot.data!;
          final name = profileData['name'];
          final email = profileData['email'];
          final joinedDate = profileData['joinedDate'];
          final totalTasks = profileData['totalTasks'];
          final completedTasks = profileData['completedTasks'];
          final pendingTasks = profileData['pendingTasks'];
          final totalMessages = profileData['totalMessages'];
          final unreadMessages = profileData['unreadMessages'];
          final totalSubjects = profileData['totalSubjects'];
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.deepPurple[100],
                          child: Text(
                            initial,
                            style: const TextStyle(fontSize: 30, color: Colors.deepPurple, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: const Text('Student', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.deepPurple,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.email, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(email),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('Joined ${DateFormat('dd/MM/yyyy').format(joinedDate)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistics',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(Icons.book, 'Total Subjects', totalSubjects),
                        _buildStatRow(Icons.task, 'Total Tasks', totalTasks),
                        _buildStatRow(Icons.check_circle_outline, 'Completed Tasks', completedTasks),
                        _buildStatRow(Icons.pending_actions, 'Pending Tasks', pendingTasks),
                        _buildStatRow(Icons.message, 'Total Messages', totalMessages),
                        _buildStatRow(Icons.mark_email_unread, 'Unread Messages', unreadMessages),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
} 