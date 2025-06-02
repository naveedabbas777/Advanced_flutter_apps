import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Authentication Methods
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String gender,
  }) async {
    try {
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes).toString();

      // Add user details to Firestore with hashed password
      await _firestore.collection('students').doc(email).set({
        'name': name,
        'email': email,
        'gender': gender,
        'passwordHash': digest,
        'role': 'student',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // No return value as UserCredential is not used
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes).toString();

      final querySnapshot = await _firestore
          .collection('students')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'student')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('User not found or not an active student.');
      }

      final userDoc = querySnapshot.docs.first;
      final storedPasswordHash = userDoc['passwordHash'] as String;

      if (storedPasswordHash != digest) {
        throw Exception('Incorrect password.');
      }

      // Save the student's email (which is also the document ID) locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', userDoc.id);

    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserId');
  }

  // Course Management Methods
  Future<void> enrollInCourse(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.collection('enrollments').add({
        'userId': userId,
        'courseId': courseId,
        'status': 'enrolled',
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      // Update course status
      await _firestore.collection('courses').doc(courseId).update({
        'enrolledStudents': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getAvailableCourses() {
    return _firestore.collection('courses').snapshots();
  }

  Stream<QuerySnapshot> getEnrolledCourses() async* {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId == null) {
      yield* Stream.empty(); // Return empty stream if not authenticated
      return;
    }
    yield* _firestore
        .collection('enrollments')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  // Task Management Methods
  Stream<QuerySnapshot> getTasksForStudent() async* {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId == null) {
      yield* Stream.empty(); // Return empty stream if not authenticated
      return;
    }
    // Assuming tasks have a 'assignedTo' field which stores student UIDs
    yield* _firestore
        .collection('tasks')
        .where('assignedTo', arrayContains: userId)
        .snapshots();
  }

  // User Profile Methods
  Future<DocumentSnapshot> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId == null) throw Exception('User not authenticated');

    return await _firestore.collection('students').doc(userId).get();
  }

  Future<void> updateUserProfile({
    String? name,
    String? gender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId == null) throw Exception('User not authenticated');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (gender != null) updates['gender'] = gender;

    await _firestore.collection('students').doc(userId).update(updates);
  }

  Future<Map<String, dynamic>> getReportForStudent() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('currentUserId');
    if (userId == null) throw Exception('User not authenticated');

    final submissionsSnapshot = await _firestore
        .collection('task_submissions')
        .where('studentId', isEqualTo: userId)
        .get();

    int total = submissionsSnapshot.docs.length;
    int completed = submissionsSnapshot.docs.where((d) => d['status'] == 'submitted').length;
    int pending = total - completed;

    return {
      'totalTasks': total,
      'completedTasks': completed,
      'pendingTasks': pending,
    };
  }
} 