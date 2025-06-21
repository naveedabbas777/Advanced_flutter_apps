import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io'; // Import for SocketException
import 'package:firebase_messaging/firebase_messaging.dart'; // Import Firebase Messaging
import '../models/user_model.dart';
import 'dart:async'; // Import for StreamSubscription
import '../services/auth_service.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  User? get currentUser => _user;
  UserModel? get userModel => _userModel;
  UserModel? get currentUserModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmailVerified => _user?.emailVerified ?? false;

  AppAuthProvider() {
    _authService.authStateChanges.listen((User? user) async {
      _user = user;
      if (user != null) {
        await _setupUserListener();
      } else {
        _userModel = null;
        _userSubscription?.cancel();
      }
      notifyListeners();
    });
  }

  Future<void> _setupUserListener() async {
    if (_user == null) return;

    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> register(String email, String password, String username) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.registerWithEmailAndPassword(email, password, username);
      await _saveFcmToken();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithEmailAndPassword(email, password);
      await _saveFcmToken();
      bool isVerified = await _authService.checkEmailVerification();
      if (!isVerified) {
        await _authService.signOut();
        _error = 'Please verify your email before logging in.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _authService.updateUserProfile(_user!.uid, {
        'lastLogin': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resetPassword(email);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resendVerificationEmail();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      return await _authService.checkEmailVerification();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
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
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update(updates);
        await _setupUserListener();
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

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'groupIds': FieldValue.arrayUnion([groupId]),
      });

      await _setupUserListener();
    } catch (e) {
      print('Error adding group to user: $e');
    }
  }

  Future<void> removeGroupFromUser(String groupId) async {
    try {
      if (_user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'groupIds': FieldValue.arrayRemove([groupId]),
      });

      await _setupUserListener();
    } catch (e) {
      print('Error removing group from user: $e');
    }
  }

  Future<void> addInvitationToUser(String invitationId) async {
    try {
      if (_user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'invitationIds': FieldValue.arrayUnion([invitationId]),
      });

      await _setupUserListener();
    } catch (e) {
      print('Error adding invitation to user: $e');
    }
  }

  Future<void> removeInvitationFromUser(String invitationId) async {
    try {
      if (_user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'invitationIds': FieldValue.arrayRemove([invitationId]),
      });

      await _setupUserListener();
    } catch (e) {
      print('Error removing invitation from user: $e');
    }
  }

  Future<void> sendGroupInvitation({
    required String groupId,
    required String memberEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final invitingUser = _authService.currentUser;
      if (invitingUser == null) {
        throw 'Inviting user not logged in.';
      }

      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        throw 'Group does not exist.';
      }
      List<String> currentMembers = List<String>.from(groupDoc.data()?['members'] ?? []);

      final invitedUserSnapshot = await FirebaseFirestore.instance
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

      final existingInvitation = await FirebaseFirestore.instance
          .collection('group_invitations')
          .where('groupId', isEqualTo: groupId)
          .where('invitedUserId', isEqualTo: invitedUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        throw 'An invitation to this user for this group is already pending.';
      }

      await FirebaseFirestore.instance.collection('group_invitations').add({
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
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final invitationRef = FirebaseFirestore.instance.collection('group_invitations').doc(invitationId);
        final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);

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
      await FirebaseFirestore.instance.collection('group_invitations').doc(invitationId).update({
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
      await FirebaseFirestore.instance.collection('groups').doc(groupId).collection('expenses').add({
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

  Future<void> _saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': fcmToken});
    }
  }
} 