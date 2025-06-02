import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoursesScreen extends StatefulWidget {
  final String studentId;
  CoursesScreen({required this.studentId});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late Future<List<Map<String, dynamic>>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _fetchSubjects();
  }

  Future<List<Map<String, dynamic>>> _fetchSubjects() async {
    // Fetch all subjects
    final allSubjectsSnapshot = await FirebaseFirestore.instance.collection('subjects').get();

    // Fetch student's registrations
    final studentRegistrationsSnapshot = await FirebaseFirestore.instance
        .collection('subject_registrations')
        .where('studentId', isEqualTo: widget.studentId)
        .get();

    Map<String, String> registrationStatuses = {};
    for (var doc in studentRegistrationsSnapshot.docs) {
      registrationStatuses[doc['subjectId']] = doc['status'];
    }

    List<Map<String, dynamic>> subjects = [];

    for (var subjectDoc in allSubjectsSnapshot.docs) {
      final subjectData = subjectDoc.data();
      final subjectId = subjectDoc.id;
      final status = registrationStatuses[subjectId]; // 'active', 'pending', 'rejected', or null

      subjects.add({
        'id': subjectId,
        'name': subjectData['name'] ?? 'N/A',
        'description': subjectData['description'] ?? 'No description',
        'status': status,
      });
    }
    return subjects;
  }

  Future<void> _requestRegistration(String subjectId) async {
    // Check if already pending or active to prevent duplicate requests
    final existingRegistration = await FirebaseFirestore.instance
        .collection('subject_registrations')
        .where('studentId', isEqualTo: widget.studentId)
        .where('subjectId', isEqualTo: subjectId)
        .limit(1)
        .get();

    if (existingRegistration.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already requested or are enrolled in this subject.')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('subject_registrations').add({
      'studentId': widget.studentId,
      'subjectId': subjectId,
      'status': 'pending',
      'registeredAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration requested successfully!')),
    );

    setState(() {
      _subjectsFuture = _fetchSubjects(); // Refresh the list
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No courses found.'));
          }

          final subjects = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final status = subject['status'];

              Widget trailingWidget;
              Color statusColor = Colors.grey;

              if (status == 'active') {
                trailingWidget = const Text(
                  'Enrolled',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                );
                statusColor = Colors.green;
              } else if (status == 'pending') {
                trailingWidget = const Text(
                  'Pending',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                );
                statusColor = Colors.orange;
              } else if (status == 'rejected') {
                trailingWidget = const Text(
                  'Rejected',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                );
                statusColor = Colors.red;
              } else {
                trailingWidget = ElevatedButton(
                  onPressed: () => _requestRegistration(subject['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Request Registration'),
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
                        subject['name'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject['description'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Status: ${status ?? 'Not Registered'}',
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          trailingWidget,
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