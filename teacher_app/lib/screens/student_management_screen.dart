import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:csv/csv.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isImporting = false;
  int _importedCount = 0;
  int _skippedCount = 0;

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Student',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: const Icon(Icons.person, color: Colors.deepPurple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Example: john.doe@gmail.com',
                    prefixIcon: const Icon(Icons.email, color: Colors.deepPurple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock, color: Colors.deepPurple),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.deepPurple,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter password' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _addStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final passwordHash = sha256.convert(utf8.encode(_passwordController.text)).toString();

    try {
      // Check if email already exists
      final emailQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (emailQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email already registered')),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('students').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'passwordHash': passwordHash,
        'joinedDate': Timestamp.now(),
        'status': 'active',
      });

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      Navigator.pop(context); // Close dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add student: $e')),
      );
    }
  }

  Future<void> _deleteStudent(String id) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete student: $e')),
      );
    }
  }

  Future<void> _updateStudentStatus(String studentId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'status': status,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Student status updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating student status: $e')),
      );
    }
  }

  Future<void> _importStudentsFromCSV() async {
    try {
      // Configure file type
      final typeGroup = XTypeGroup(
        label: 'CSV',
        extensions: ['csv'],
      );

      // Pick file
      final file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (file == null) return;

      setState(() {
        _isImporting = true;
        _importedCount = 0;
        _skippedCount = 0;
      });

      // Read file content
      final fileContent = await file.readAsString();
      final rows = const CsvToListConverter().convert(fileContent);

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file is empty')),
        );
        return;
      }

      // Skip header row if present
      final startIndex = rows.first.contains('name') || 
                        rows.first.contains('email') || 
                        rows.first.contains('password') ? 1 : 0;

      for (var i = startIndex; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) {
          setState(() => _skippedCount++);
          continue;
        }

        final name = row[0].toString().trim();
        final email = row[1].toString().trim();
        final password = row[2].toString().trim();

        if (name.isEmpty || email.isEmpty || password.isEmpty) {
          setState(() => _skippedCount++);
          continue;
        }

        // Check if email already exists
        final emailQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('email', isEqualTo: email)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          setState(() => _skippedCount++);
          continue;
        }

        final passwordHash = sha256.convert(utf8.encode(password)).toString();

        await FirebaseFirestore.instance.collection('students').add({
          'name': name,
          'email': email,
          'passwordHash': passwordHash,
          'joinedDate': Timestamp.now(),
          'status': 'active',
        });

        setState(() => _importedCount++);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $_importedCount students, skipped $_skippedCount invalid entries',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isImporting = false);
    }
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
        title: Row(
          children: [
            Icon(Icons.school, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              'Students',
              style: TextStyle(color: Colors.grey[800]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue[700]),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('students').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final students = snapshot.data!.docs;

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No students yet',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first student using the + button',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final studentDoc = students[index];
                        final studentData = studentDoc.data() as Map<String, dynamic>;
                        final studentId = studentDoc.id;
                        final studentName = studentData['name'] ?? 'Unknown Student';
                        final studentStatus = studentData['status'] ?? 'N/A';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            title: Text(studentName),
                            subtitle: Text('Status: ${studentStatus.toUpperCase()}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _deleteStudent(studentId),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (String result) {
                                    _updateStudentStatus(studentId, result);
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'active',
                                      child: Text('Set Active'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'inactive',
                                      child: Text('Set Inactive'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (students.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.green,
                      child: Center(
                        child: Text(
                          'Added ${students.length} students, skipped 0 students',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (_isImporting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Importing students...\nImported: $_importedCount\nSkipped: $_skippedCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'import',
            backgroundColor: Colors.white,
            onPressed: _importStudentsFromCSV,
            child: const Icon(Icons.file_upload, color: Colors.deepPurple),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add',
            backgroundColor: Colors.deepPurple[100],
            onPressed: _showAddStudentDialog,
            child: const Icon(Icons.add, color: Colors.deepPurple),
          ),
        ],
      ),
    );
  }
} 