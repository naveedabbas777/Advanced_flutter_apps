import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class StudentTaskScreen extends StatefulWidget {
  final String studentId;
  const StudentTaskScreen({required this.studentId});

  @override
  State<StudentTaskScreen> createState() => _StudentTaskScreenState();
}

class _StudentTaskScreenState extends State<StudentTaskScreen> {
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _fetchTasks();
  }

  Future<List<Map<String, dynamic>>> _fetchTasks() async {
    final taskSnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('assignedTo', isEqualTo: widget.studentId) // Updated to single student ID
        .orderBy('dueDate')
        .get();

    List<Map<String, dynamic>> tasks = [];
    for (var doc in taskSnapshot.docs) {
      final taskData = doc.data();
      // Check if the task has already been submitted by this student
      final submissionSnapshot = await FirebaseFirestore.instance
          .collection('task_submissions')
          .where('taskId', isEqualTo: doc.id)
          .where('studentId', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      bool isSubmitted = submissionSnapshot.docs.isNotEmpty;

      tasks.add({
        'id': doc.id,
        'title': taskData['title'] ?? 'N/A',
        'description': taskData['description'] ?? 'No description',
        'dueDate': (taskData['dueDate'] as Timestamp?)?.toDate(),
        'status': taskData['status'] ?? 'pending',
        'isSubmitted': isSubmitted,
      });
    }
    return tasks;
  }

  Future<void> _submitTask(BuildContext context, String taskId) async {
    try {
      final XFile? file = await openFile();

      if (file != null) {
        final path = file.path;
        final fileName = file.name;

        final ref = FirebaseStorage.instance.ref(
          'task_submissions/${widget.studentId}/$taskId/$fileName',
        );
        await ref.putFile(File(path));

        final fileUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('task_submissions').add({
          'taskId': taskId,
          'studentId': widget.studentId,
          'fileUrl': fileUrl,
          'status': 'submitted',
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task submitted successfully!')),
        );

        setState(() {
          _tasksFuture = _fetchTasks();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File upload failed: $e')),
      );
    }
  }

  Future<void> _markTaskAsCompleted(String taskId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'status': 'completed',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task marked as completed!')),
    );

    setState(() {
      _tasksFuture = _fetchTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tasks assigned.'));
          }

          final tasks = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final dueDate = task['dueDate'] != null
                  ? DateFormat('dd/MM/yyyy').format(task['dueDate'])
                  : 'N/A';
              final taskStatus = task['status'] ?? 'pending';
              final isSubmitted = task['isSubmitted'] ?? false;

              Widget actionButton;
              if (taskStatus == 'completed') {
                actionButton = const Text(
                  'Completed',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                );
              } else if (isSubmitted) {
                actionButton = const Text(
                  'Submitted',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                );
              } else {
                actionButton = Wrap(
                  spacing: 8.0, // horizontal spacing between buttons
                  runSpacing: 4.0, // vertical spacing between lines
                  children: [
                    ElevatedButton(
                      onPressed: () => _submitTask(context, task['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Submit Work'),
                    ),
                    ElevatedButton(
                      onPressed: () => _markTaskAsCompleted(task['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Mark as Completed'),
                    ),
                  ],
                );
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Due: ${dueDate}'),
                                Text('Status: ${taskStatus[0].toUpperCase()}${taskStatus.substring(1)}'),
                              ],
                            ),
                          ),
                          actionButton,
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