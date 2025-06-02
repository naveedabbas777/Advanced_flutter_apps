import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedStudentId = prefs.getString('studentId');

  runApp(MyApp(savedStudentId: savedStudentId));
}

class MyApp extends StatelessWidget {
  final String? savedStudentId;
  MyApp({this.savedStudentId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          savedStudentId == null
              ? LoginScreen()
              : HomeScreen(studentId: savedStudentId!),
    );
  }
}
