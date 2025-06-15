import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

class AppAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;

  AppAuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData();
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get currentUser => _user;

  Future<void> _loadUserData() async {
    if (_user != null) {
      try {
        _userData = await _firestore.collection('users').doc(_user!.uid).get().then((doc) => doc.data());
        notifyListeners();
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> register(String email, String password, String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      // // Verify reCAPTCHA token
      // final response = await http.post(
      //   Uri.parse('https://www.google.com/recaptcha/api/siteverify'),
      //   body: {
      //     'secret': 'YOUR_RECAPTCHA_SECRET_KEY',
      //     'response': recaptchaToken,
      //   },
      // );

      // final responseData = json.decode(response.body);
      // if (!responseData['success']) {
      //   throw 'reCAPTCHA verification failed';
      // }

      // Create user account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // // Verify reCAPTCHA token
      // final response = await http.post(
      //   Uri.parse('https://www.google.com/recaptcha/api/siteverify'),
      //   body: {
      //     'secret': 'YOUR_RECAPTCHA_SECRET_KEY',
      //     'response': recaptchaToken,
      //   },
      // );

      // final responseData = json.decode(response.body);
      // if (!responseData['success']) {
      //   throw 'reCAPTCHA verification failed';
      // }

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'An error occurred while resetting password';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 