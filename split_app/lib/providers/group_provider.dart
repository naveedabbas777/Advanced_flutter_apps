import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import 'package:rxdart/rxdart.dart' show combineLatestList;

class GroupProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _error;
  List<GroupModel> _groups = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<GroupModel> get groups => _groups;

  Stream<List<GroupModel>> getUserGroupsStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncExpand((userDoc) {
      if (!userDoc.exists || userDoc.data()?['groupIds'] == null) {
        return Stream.value([]);
      }
      final List<String> groupIds = List<String>.from(userDoc.data()!['groupIds']);

      if (groupIds.isEmpty) {
        return Stream.value([]);
      }

      // Fetch group details for each group ID. Using a batch read for efficiency.
      // However, Firestore does not support 'whereIn' for more than 10 items
      // and it doesn't give real-time updates for individual documents when using batch get.
      // For real-time updates, we need to listen to each group document individually or query by ID in batches.
      // For simplicity and real-time updates, we will listen to each individually.
      final groupStreams = groupIds.map((id) => _firestore.collection('groups').doc(id).snapshots()).toList();

      return Stream.combineLatestList(groupStreams).map((snapshots) {
        return snapshots
            .where((snapshot) => snapshot.exists)
            .map((snapshot) => GroupModel.fromFirestore(snapshot))
            .toList();
      });
    });
  }

  Future<void> createGroup(String name, UserModel creator) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create group document
      final groupRef = await _firestore.collection('groups').add({
        'name': name,
        'createdBy': creator.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'members': [
          {
            'userId': creator.uid,
            'username': creator.username,
            'email': creator.email,
            'isAdmin': true,
            'joinedAt': FieldValue.serverTimestamp(),
          }
        ],
      });

      // Add group to creator's groups list
      await _firestore.collection('users').doc(creator.uid).update({
        'groupIds': FieldValue.arrayUnion([groupRef.id]),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to create group: $e';
      notifyListeners();
    }
  }

  Future<void> loadUserGroups(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get user's group IDs
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final groupIds = List<String>.from(userData?['groupIds'] ?? []);

      // Load group details
      _groups = [];
      for (String groupId in groupIds) {
        final groupDoc = await _firestore.collection('groups').doc(groupId).get();
        if (groupDoc.exists) {
          _groups.add(GroupModel.fromFirestore(groupDoc));
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load groups: $e';
      notifyListeners();
    }
  }

  Future<void> inviteUserToGroup({
    required String groupId,
    required String invitedBy,
    required String invitedByUsername,
    required String invitedUserEmail,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check if user exists
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: invitedUserEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        throw 'User not found';
      }

      final invitedUser = userQuery.docs.first;
      final invitedUserId = invitedUser.id;

      // Check if user is already a member
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final group = GroupModel.fromFirestore(groupDoc);
      
      if (group.members.any((member) => member.userId == invitedUserId)) {
        throw 'User is already a member of this group';
      }

      // Create invitation
      await _firestore.collection('invitations').add({
        'groupId': groupId,
        'groupName': group.name,
        'invitedBy': invitedBy,
        'invitedByUsername': invitedByUsername,
        'invitedUserId': invitedUserId,
        'invitedUserEmail': invitedUserEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add invitation to user's invitations list
      await _firestore.collection('users').doc(invitedUserId).update({
        'invitationIds': FieldValue.arrayUnion([groupId]),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to invite user: $e';
      notifyListeners();
    }
  }

  Future<void> acceptInvitation({
    required String invitationId,
    required String groupId,
    required UserModel user,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Add user to group members
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([
          {
            'userId': user.uid,
            'username': user.username,
            'email': user.email,
            'isAdmin': false,
            'joinedAt': FieldValue.serverTimestamp(),
          }
        ]),
      });

      // Add group to user's groups list
      await _firestore.collection('users').doc(user.uid).update({
        'groupIds': FieldValue.arrayUnion([groupId]),
        'invitationIds': FieldValue.arrayRemove([groupId]),
      });

      // Update invitation status
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to accept invitation: $e';
      notifyListeners();
    }
  }

  Future<void> rejectInvitation({
    required String invitationId,
    required String groupId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Remove invitation from user's invitations list
      await _firestore.collection('users').doc(userId).update({
        'invitationIds': FieldValue.arrayRemove([groupId]),
      });

      // Update invitation status
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to reject invitation: $e';
      notifyListeners();
    }
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
    required String removedBy,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get group data
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final group = GroupModel.fromFirestore(groupDoc);

      // Check if remover is admin
      final remover = group.members.firstWhere(
        (member) => member.userId == removedBy,
        orElse: () => throw 'You are not a member of this group',
      );

      if (!remover.isAdmin) {
        throw 'Only group admins can remove members';
      }

      // Remove member from group
      final memberToRemove = group.members.firstWhere(
        (member) => member.userId == userId,
        orElse: () => throw 'Member not found in group',
      );

      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([memberToRemove.toMap()]),
      });

      // Remove group from user's groups list
      await _firestore.collection('users').doc(userId).update({
        'groupIds': FieldValue.arrayRemove([groupId]),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to remove member: $e';
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
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .add({
        'description': description,
        'amount': amount,
        'paidBy': paidBy,
        'splitAmong': splitAmong,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to add expense: \$e';
      notifyListeners();
    }
  }
} 