import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;
  final coursesCollection = firestore.collection('courses');

  // Initial courses data
  final courses = [
    {
      'name': 'Flutter Development',
      'description': 'Learn to build beautiful cross-platform apps',
      'status': 'active',
      'enrolledStudents': [],
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Python Programming',
      'description': 'Master Python programming language',
      'status': 'active',
      'enrolledStudents': [],
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Web Development',
      'description': 'Full-stack web development course',
      'status': 'active',
      'enrolledStudents': [],
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Data Structures & Algorithms',
      'description': 'Learn fundamental computer science concepts',
      'status': 'active',
      'enrolledStudents': [],
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Machine Learning',
      'description': 'Introduction to machine learning and AI',
      'status': 'active',
      'enrolledStudents': [],
      'createdAt': FieldValue.serverTimestamp(),
    },
  ];

  // Add courses to Firestore
  for (final course in courses) {
    try {
      await coursesCollection.add(course);
      print('Added course: ${course['name']}');
    } catch (e) {
      print('Error adding course ${course['name']}: $e');
    }
  }

  print('Finished populating courses');
}
