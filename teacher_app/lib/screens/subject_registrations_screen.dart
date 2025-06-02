import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectRegistrationsScreen extends StatefulWidget {
  final String teacherId;

  const SubjectRegistrationsScreen({super.key, required this.teacherId});

  @override
  State<SubjectRegistrationsScreen> createState() => _SubjectRegistrationsScreenState();
}

class _SubjectRegistrationsScreenState extends State<SubjectRegistrationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateRegistrationStatus(String registrationId, String status) async {
    try {
      await _firestore.collection('subject_registrations').doc(registrationId).update({
        'status': status,
        'teacherApprovedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration status updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Registrations'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('subjects').orderBy('name').snapshots(),
        builder: (context, subjectSnapshot) {
          if (subjectSnapshot.hasError) {
            return Center(child: Text('Error: ${subjectSnapshot.error}'));
          }
          if (subjectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final subjects = subjectSnapshot.data!.docs;

          if (subjects.isEmpty) {
            return const Center(child: Text('No subjects available.'));
          }

          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final subjectId = subject.id;
              final subjectName = subject['name'] as String;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ExpansionTile(
                  title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('subject_registrations')
                          .where('subjectId', isEqualTo: subjectId)
                          .snapshots(),
                      builder: (context, registrationSnapshot) {
                        if (registrationSnapshot.hasError) {
                          return Text('Error: ${registrationSnapshot.error}');
                        }
                        if (registrationSnapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        final registrations = registrationSnapshot.data!.docs;

                        if (registrations.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No pending registrations for this subject.'),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: registrations.length,
                          itemBuilder: (context, regIndex) {
                            final registration = registrations[regIndex];
                            final studentId = registration['studentId'] as String;
                            final status = registration['status'] as String;

                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('students').doc(studentId).get(),
                              builder: (context, studentSnapshot) {
                                if (studentSnapshot.connectionState == ConnectionState.waiting) {
                                  return const ListTile(title: Text('Loading student...'));
                                }
                                if (studentSnapshot.hasError) {
                                  return ListTile(title: Text('Error loading student: ${studentSnapshot.error}'));
                                }
                                if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
                                  return const ListTile(title: Text('Student not found.'));
                                }

                                final studentData = studentSnapshot.data!.data() as Map<String, dynamic>;
                                final studentName = studentData['name'] as String? ?? 'Unknown Student';

                                return ListTile(
                                  title: Text('$studentName ($status)'),
                                  trailing: status == 'pending'
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.check_circle, color: Colors.green),
                                              onPressed: () => _updateRegistrationStatus(registration.id, 'active'),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.cancel, color: Colors.red),
                                              onPressed: () => _updateRegistrationStatus(registration.id, 'rejected'),
                                            ),
                                          ],
                                        )
                                      : null,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
} 