import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Authentication Methods
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String gender,
  }) async {
    try {
      // Create user with email and password
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Add user details to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Course Management Methods
  Future<void> enrollInCourse(String courseId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore.collection('enrollments').add({
        'userId': user.uid,
        'courseId': courseId,
        'status': 'enrolled',
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      // Update course status
      await _firestore.collection('courses').doc(courseId).update({
        'enrolledStudents': FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getAvailableCourses() {
    return _firestore.collection('courses').snapshots();
  }

  Stream<QuerySnapshot> getEnrolledCourses() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('enrollments')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  // User Profile Methods
  Future<DocumentSnapshot> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return await _firestore.collection('users').doc(user.uid).get();
  }

  Future<void> updateUserProfile({String? name, String? gender}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (gender != null) updates['gender'] = gender;

    await _firestore.collection('users').doc(user.uid).update(updates);
  }
}
