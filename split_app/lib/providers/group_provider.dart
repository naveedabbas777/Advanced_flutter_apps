import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> createGroup(String groupName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'User not logged in.';
      }

      await _firestore.collection('groups').add({
        'name': groupName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'members': [user.uid], // Creator is automatically a member
      });
    } catch (e) {
      throw 'Failed to create group: $e';
    } finally {
      _isLoading = false;
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

      // Check for existing pending invitation
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