import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ReportsScreen extends StatefulWidget {
  final String studentId;
  ReportsScreen({required this.studentId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _reportDataController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  StreamSubscription<QuerySnapshot>? _submissionsSubscription;

  QuerySnapshot? _latestTasksSnapshot;
  QuerySnapshot? _latestSubmissionsSnapshot;

  @override
  void initState() {
    super.initState();
    _subscribeToReportData();
  }

  void _subscribeToReportData() {
    _tasksSubscription = _firestore
        .collection('tasks')
        .where('assignedTo', isEqualTo: widget.studentId) // Ensure this matches your Firestore structure
        .snapshots()
        .listen((snapshot) {
      _latestTasksSnapshot = snapshot;
      _updateReportData();
    });

    _submissionsSubscription = _firestore
        .collection('task_submissions')
        .where('studentId', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _latestSubmissionsSnapshot = snapshot;
      _updateReportData();
    });
  }

  void _updateReportData() {
    if (_latestTasksSnapshot == null) return;

    int totalTasks = 0;
    int completedTasks = 0;
    int submittedTasks = 0;
    int pendingTasks = 0;
    List<Map<String, dynamic>> expiredTasks = [];

    final now = DateTime.now();

    // Process tasks
    totalTasks = _latestTasksSnapshot!.docs.length;

    for (var taskDoc in _latestTasksSnapshot!.docs) {
      final taskData = taskDoc.data() as Map<String, dynamic>;
      final taskId = taskDoc.id;

      bool isTaskCompleted = taskData['status'] == 'completed';

      // Check for submission status from task_submissions snapshot
      bool isTaskSubmitted = _latestSubmissionsSnapshot?.docs.any(
            (submissionDoc) => submissionDoc['taskId'] == taskId,
          ) ??
          false;

      if (isTaskCompleted) {
        completedTasks++;
      }

      if (isTaskSubmitted) {
        submittedTasks++;
      }

      // A task is pending if it's not completed and not submitted
      if (!isTaskCompleted && !isTaskSubmitted) {
        pendingTasks++;
      }

      // Check for expired tasks
      final dueDateTimestamp = taskData['dueDate'] as Timestamp?;
      if (dueDateTimestamp != null) {
        final dueDate = dueDateTimestamp.toDate();
        if (dueDate.isBefore(now) && !isTaskCompleted && !isTaskSubmitted) {
          expiredTasks.add({
            'id': taskId,
            'title': taskData['title'] ?? 'N/A',
            'dueDate': dueDate,
          });
        }
      }
    }

    // The sum of these categories should equal totalTasks
    // totalTasks = completedTasks + pendingTasks + submittedTasks (with submitted including completed if that's your model)
    // For our simplified model, we'll calculate pending explicitly

    _reportDataController.add({
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'pendingTasks': pendingTasks,
      'submittedTasks': submittedTasks,
      'expiredTasks': expiredTasks,
    });
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _submissionsSubscription?.cancel();
    _reportDataController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _reportDataController.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No report data found.'));
          }

          final reportData = snapshot.data!;
          final List<Map<String, dynamic>> expiredTasks = reportData['expiredTasks'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Task Performance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildReportRow(Icons.playlist_add_check, 'Total Assigned Tasks', reportData['totalTasks']),
                _buildReportRow(Icons.check_circle_outline, 'Completed Tasks', reportData['completedTasks']),
                _buildReportRow(Icons.upload_file, 'Submitted Tasks', reportData['submittedTasks']),
                _buildReportRow(Icons.pending_actions, 'Pending Tasks', reportData['pendingTasks']),
                const SizedBox(height: 24),
                if (expiredTasks.isNotEmpty) ...[
                  const Text(
                    'Expired Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expiredTasks.length,
                    itemBuilder: (context, index) {
                      final expiredTask = expiredTasks[index];
                      final dueDate = DateFormat('dd/MM/yyyy').format(expiredTask['dueDate']);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        elevation: 1,
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.orangeAccent),
                          title: Text(expiredTask['title']),
                          subtitle: Text('Due: $dueDate'),
                        ),
                      );
                    },
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportRow(IconData icon, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
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