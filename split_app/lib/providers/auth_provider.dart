import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io'; // Import for SocketException
import 'package:firebase_messaging/firebase_messaging.dart'; // Import Firebase Messaging
import '../models/user_model.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmailVerified => _user?.emailVerified ?? false;

  AppAuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserData();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      }
      notifyListeners();
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> register(String email, String password, String username) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Attempting to sign up with email: $email');

      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile with username
      await userCredential.user?.updateDisplayName(username);

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Create user document in Firestore
      final userModel = UserModel(
        uid: userCredential.user!.uid,
        username: username,
        email: email,
        groupIds: [],
        invitationIds: [],
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set(userModel.toMap());

      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      switch (e.code) {
        case 'email-already-in-use':
          _error = 'This email is already registered.';
          break;
        case 'invalid-email':
          _error = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          _error = 'Password is too weak. Please use a stronger password.';
          break;
        default:
          _error = 'An error occurred during registration: ${e.message}';
      }
      notifyListeners();
    } on SocketException {
      _isLoading = false;
      _error = 'No internet connection. Please check your connection and try again.';
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'An unexpected error occurred: $e';
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Attempting to sign in with email: $email');

      // Sign in user
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Sign in successful, checking email verification...');

      // Force reload user to get latest email verification status
      await userCredential.user?.reload();
      User? updatedUser = _auth.currentUser;

      print('User email verification status: ${updatedUser?.emailVerified}');
      print('User email: ${updatedUser?.email}');

      // Check if email is verified
      if (updatedUser == null) {
        _error = 'Failed to get user information. Please try again.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (!updatedUser.emailVerified) {
        print('Email not verified, signing out...');
        await _auth.signOut();
        _error = 'Please verify your email before logging in.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      print('Email verified, proceeding with login...');

      // Update last login time
      await _firestore.collection('users').doc(updatedUser.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Load user data
      await _loadUserData();

      _isLoading = false;
      notifyListeners();
      print('Login process completed successfully');
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during login: ${e.code} - ${e.message}');
      _isLoading = false;
      switch (e.code) {
        case 'user-not-found':
          _error = 'No user found with this email.';
          break;
        case 'wrong-password':
          _error = 'Incorrect password.';
          break;
        case 'invalid-email':
          _error = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          _error = 'This account has been disabled.';
          break;
        default:
          _error = 'An error occurred during login: ${e.message}';
      }
      notifyListeners();
    } on SocketException {
      print('SocketException during login: No internet connection');
      _isLoading = false;
      _error = 'No internet connection. Please check your connection and try again.';
      notifyListeners();
    } catch (e) {
      print('Unexpected error during login: $e');
      _isLoading = false;
      _error = 'An unexpected error occurred: $e';
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? username}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_user == null) {
        throw 'No user is currently signed in';
      }

      // Update username in Firebase Auth
      if (username != null) {
        await _user!.updateDisplayName(username);
      }

      // Update user document in Firestore
      Map<String, dynamic> updates = {};
      if (username != null) {
        updates['username'] = username;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(_user!.uid).update(updates);
        await _loadUserData(); // Reload user data
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to update profile: $e';
      notifyListeners();
    }
  }

  Future<void> addGroupToUser(String groupId) async {
    try {
      if (_user == null) return;

      await _firestore.collection('users').doc(_user!.uid).update({
        'groupIds': FieldValue.arrayUnion([groupId]),
      });

      await _loadUserData();
    } catch (e) {
      print('Error adding group to user: $e');
    }
  }

  Future<void> removeGroupFromUser(String groupId) async {
    try {
      if (_user == null) return;

      await _firestore.collection('users').doc(_user!.uid).update({
        'groupIds': FieldValue.arrayRemove([groupId]),
      });

      await _loadUserData();
    } catch (e) {
      print('Error removing group from user: $e');
    }
  }

  Future<void> addInvitationToUser(String invitationId) async {
    try {
      if (_user == null) return;

      await _firestore.collection('users').doc(_user!.uid).update({
        'invitationIds': FieldValue.arrayUnion([invitationId]),
      });

      await _loadUserData();
    } catch (e) {
      print('Error adding invitation to user: $e');
    }
  }

  Future<void> removeInvitationFromUser(String invitationId) async {
    try {
      if (_user == null) return;

      await _firestore.collection('users').doc(_user!.uid).update({
        'invitationIds': FieldValue.arrayRemove([invitationId]),
      });

      await _loadUserData();
    } catch (e) {
      print('Error removing invitation from user: $e');
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.signOut();
      _userModel = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'An error occurred during logout: $e';
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);

      _isLoading = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      switch (e.code) {
        case 'user-not-found':
          _error = 'No user found with this email.';
          break;
        case 'invalid-email':
          _error = 'Please enter a valid email address.';
          break;
        default:
          _error = 'An error occurred while sending password reset email: ${e.message}';
      }
      notifyListeners();
    } on SocketException {
      _isLoading = false;
      _error = 'No internet connection. Please check your connection and try again.';
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'An unexpected error occurred: $e';
      notifyListeners();
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      print('Checking email verification status...');
      if (_user != null) {
        print('Current user email: ${_user?.email}');
        print('Current verification status: ${_user?.emailVerified}');
        
        await _user!.reload();
        _user = _auth.currentUser;
        
        print('After reload - User email: ${_user?.email}');
        print('After reload - Verification status: ${_user?.emailVerified}');
        
        return _user?.emailVerified ?? false;
      }
      print('No user is currently signed in');
      return false;
    } catch (e) {
      print('Error checking email verification: $e');
      _error = 'Failed to check email verification status: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Attempting to resend verification email...');

      if (_user != null) {
        print('Sending verification email to: ${_user?.email}');
        await _user!.sendEmailVerification();
        print('Verification email sent successfully');
        _isLoading = false;
        notifyListeners();
      } else {
        print('No user is currently signed in');
        _error = 'No user is currently signed in.';
        _isLoading = false;
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during resend: ${e.code} - ${e.message}');
      _isLoading = false;
      _error = 'Failed to send verification email: ${e.message}';
      notifyListeners();
    } on SocketException {
      print('SocketException during resend: No internet connection');
      _isLoading = false;
      _error = 'No internet connection. Please check your connection and try again.';
      notifyListeners();
    } catch (e) {
      print('Unexpected error during resend: $e');
      _isLoading = false;
      _error = 'An unexpected error occurred: $e';
      notifyListeners();
    }
  }

  Future<void> sendGroupInvitation({
    required String groupId,
    required String memberEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final invitingUser = _auth.currentUser;
      if (invitingUser == null) {
        throw 'Inviting user not logged in.';
      }

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        throw 'Group does not exist.';
      }
      List<String> currentMembers = List<String>.from(groupDoc.data()?['members'] ?? []);

      final invitedUserSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: memberEmail)
          .limit(1)
          .get();

      if (invitedUserSnapshot.docs.isEmpty) {
        throw 'User with this email does not exist in the app.';
      }

      final invitedUserId = invitedUserSnapshot.docs.first.id;

      if (currentMembers.contains(invitedUserId)) {
        throw 'This user is already a member of this group.';
      }

      final existingInvitation = await _firestore
          .collection('group_invitations')
          .where('groupId', isEqualTo: groupId)
          .where('invitedUserId', isEqualTo: invitedUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        throw 'An invitation to this user for this group is already pending.';
      }

      await _firestore.collection('group_invitations').add({
        'groupId': groupId,
        'groupName': groupDoc.data()?['name'] ?? 'Unnamed Group',
        'invitedByUserId': invitingUser.uid,
        'invitedUserEmail': memberEmail,
        'invitedUserId': invitedUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to send invitation: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptGroupInvitation(String invitationId, String groupId, String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.runTransaction((transaction) async {
        final invitationRef = _firestore.collection('group_invitations').doc(invitationId);
        final groupRef = _firestore.collection('groups').doc(groupId);

        final invitationDoc = await transaction.get(invitationRef);
        if (!invitationDoc.exists || invitationDoc.data()?['status'] != 'pending') {
          throw 'Invitation not found or no longer pending.';
        }

        final groupDoc = await transaction.get(groupRef);
        if (!groupDoc.exists) {
          throw 'Group does not exist.';
        }

        List<dynamic> currentMembers = groupDoc.data()?['members'] ?? [];
        if (currentMembers.contains(userId)) {
          // Already a member, just update invitation status
        } else {
          transaction.update(groupRef, {
            'members': FieldValue.arrayUnion([userId]),
          });
        }
        transaction.update(invitationRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw 'Failed to accept invitation: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectGroupInvitation(String invitationId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.collection('group_invitations').doc(invitationId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to reject invitation: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required List<String> splitAmong,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestore.collection('groups').doc(groupId).collection('expenses').add({
        'description': description,
        'amount': amount,
        'paidBy': paidBy,
        'splitAmong': splitAmong,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to add expense: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 