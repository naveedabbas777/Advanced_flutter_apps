import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class TaskScreen extends StatefulWidget {
  final String teacherId;
  const TaskScreen({required this.teacherId});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController = TextEditingController();
  DateTime? _selectedDueDate;
  List<Map<String, dynamic>> _allStudents = [];
  String? _selectedStudentId; // Changed to single student selection
  String? _selectedStudentName; // Added for single student name

  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _tasksFuture = _fetchTasks();
  }

  Future<void> _fetchStudents() async {
    final studentSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('status', isEqualTo: 'active') // Only active students
        .get();
    setState(() {
      _allStudents = studentSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'] ?? 'Unknown Student',
      }).toList();
      // Optionally pre-select the first student if available
      if (_allStudents.isNotEmpty) {
        _selectedStudentId = _allStudents.first['id'];
        _selectedStudentName = _allStudents.first['name'];
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchTasks() async {
    final taskSnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('teacherId', isEqualTo: widget.teacherId)
        .orderBy('dueDate')
        .get();

    List<Map<String, dynamic>> tasks = [];
    for (var doc in taskSnapshot.docs) {
      final taskData = doc.data();
      tasks.add({
        'id': doc.id,
        'title': taskData['title'] ?? 'N/A',
        'description': taskData['description'] ?? 'No description',
        'dueDate': (taskData['dueDate'] as Timestamp?)?.toDate(),
        'assignedTo': taskData['assignedTo'], // Single student ID
        'studentName': taskData['studentName'] ?? 'N/A', // Single student name
        'status': taskData['status'] ?? 'pending',
      });
    }
    return tasks;
  }

  Future<void> _createTask() async {
    if (_taskTitleController.text.trim().isEmpty ||
        _selectedDueDate == null ||
        _selectedStudentId == null) { // Check for single selected student
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields and assign a student.')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('tasks').add({
      'teacherId': widget.teacherId,
      'title': _taskTitleController.text.trim(),
      'description': _taskDescriptionController.text.trim(),
      'dueDate': Timestamp.fromDate(_selectedDueDate!),
      'assignedTo': _selectedStudentId, // Single student ID
      'studentName': _selectedStudentName, // Single student name
      'status': 'pending', // Initial status is pending
      'createdAt': FieldValue.serverTimestamp(),
    });

    _taskTitleController.clear();
    _taskDescriptionController.clear();
    setState(() {
      _selectedDueDate = null;
      // _selectedStudentId and _selectedStudentName might be reset or kept for convenience
      _tasksFuture = _fetchTasks(); // Refresh tasks list
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task created and assigned successfully!')),
    );
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _viewSubmissions(String taskId) {
    // TODO: Implement navigation to a new screen to view task submissions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View submissions for task $taskId (Not implemented yet).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tasks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New Task',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _taskTitleController,
              decoration: const InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: _taskDescriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            ListTile(
              title: Text(_selectedDueDate == null
                  ? 'Select Due Date'
                  : 'Due Date: ${DateFormat('dd/MM/yyyy').format(_selectedDueDate!)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDueDate(context),
            ),
            const SizedBox(height: 16),
            const Text('Assign to Student:', style: TextStyle(fontWeight: FontWeight.bold)),
            _allStudents.isEmpty
                ? const Text('No active students available.')
                : DropdownButtonFormField<String>(
                    value: _selectedStudentId,
                    hint: const Text('Select a student'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedStudentId = newValue;
                        _selectedStudentName = _allStudents
                            .firstWhere((student) => student['id'] == newValue)['name'];
                      });
                    },
                    items: _allStudents.map<DropdownMenuItem<String>>((student) {
                      return DropdownMenuItem<String>(
                        value: student['id'],
                        child: Text(student['name']),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createTask,
              child: const Text('Create Task'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Your Assigned Tasks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _tasksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());

                  if (snapshot.hasError)
                    return Center(child: Text('Error: ${snapshot.error}'));

                  if (!snapshot.hasData || snapshot.data!.isEmpty)
                    return const Center(child: Text('No tasks assigned by you.'));

                  final tasks = snapshot.data!;

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final dueDate = task['dueDate'] != null
                          ? DateFormat('dd/MM/yyyy').format(task['dueDate'])
                          : 'N/A';
                      final taskStatus = task['status'] ?? 'pending';
                      final assignedStudentName = task['studentName'] ?? 'N/A';

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
                              Text('Due: ${dueDate}'),
                              Text('Assigned to: ${assignedStudentName}'),
                              Text('Status: ${taskStatus[0].toUpperCase()}${taskStatus.substring(1)}'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _viewSubmissions(task['id']),
                                child: const Text('View Submissions'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 