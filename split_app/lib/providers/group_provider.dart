import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';

class GroupProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _error;
  List<GroupModel> _groups = [];
  final _loadingController = StreamController<bool>.broadcast();

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<GroupModel> get groups => _groups;
  Stream<bool> get loadingStream => _loadingController.stream;

  @override
  void dispose() {
    _loadingController.close();
    super.dispose();
  }

  Stream<List<GroupModel>> getUserGroupsStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncExpand((userDoc) {
      if (!userDoc.exists || userDoc.data()?['groupIds'] == null) {
        return Stream.value(<GroupModel>[]);
      }
      final List<String> groupIds = List<String>.from(userDoc.data()!['groupIds']);

      if (groupIds.isEmpty) {
        return Stream.value(<GroupModel>[]);
      }

      // Create a list of streams for each group
      final groupStreams = groupIds.map((id) => 
        _firestore.collection('groups').doc(id).snapshots()
      ).toList();

      // Use Rx.combineLatestList to combine the streams
      return Rx.combineLatestList<DocumentSnapshot>(
        groupStreams,
      ).map((snapshots) => snapshots
          .where((snapshot) => snapshot.exists)
          .map((snapshot) => GroupModel.fromFirestore(snapshot))
          .toList());
    });
  }

  Future<void> createGroup(String name, UserModel creator, {String? photoUrl}) async {
    try {
      _setLoading(true);
      _error = null;

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
            'joinedAt': Timestamp.fromDate(DateTime.now()),
          }
        ],
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      // Add group to creator's groups list
      await _firestore.collection('users').doc(creator.uid).update({
        'groupIds': FieldValue.arrayUnion([groupRef.id]),
      });

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _error = 'Failed to create group: $e';
      notifyListeners();
    }
  }

  Future<void> loadUserGroups(String userId) async {
    try {
      _setLoading(true);
      _error = null;

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

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
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
      _setLoading(true);
      _error = null;

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
      await _firestore.collection('group_invitations').add({
        'groupId': groupId,
        'groupName': group.name,
        'invitedBy': invitedBy,
        'invitedByUsername': invitedByUsername,
        'invitedUserId': invitedUserId,
        'invitedUserEmail': invitedUserEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add invitation to user's invitations list (this is handled by the invitation itself, no need for invitationIds array in user doc)
      // The user will see invitations in their InvitationsScreen by querying the group_invitations collection.
      // If you still want to track invitation IDs on the user document, ensure they are also updated when invitations are accepted/rejected

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _error = 'Failed to invite user: $e';
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _loadingController.add(value);
    notifyListeners();
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
            'joinedAt': Timestamp.fromDate(DateTime.now()),
          }
        ]),
      });

      // Add group to user's groups list
      await _firestore.collection('users').doc(user.uid).update({
        'groupIds': FieldValue.arrayUnion([groupId]),
        // 'invitationIds': FieldValue.arrayRemove([groupId]), // Remove if not explicitly used
      });

      // Update invitation status
      await _firestore.collection('group_invitations').doc(invitationId).update({
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

      // Remove invitation from user's invitations list (if this array is still used)
      // await _firestore.collection('users').doc(userId).update({
      //   'invitationIds': FieldValue.arrayRemove([groupId]),
      // });

      // Update invitation status
      await _firestore.collection('group_invitations').doc(invitationId).update({
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
    required DateTime expenseDate,
    String? notes,
    List<String>? splitAmong,
    Map<String, double>? customSplitAmounts,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Determine split type and data to store
      String splitType;
      dynamic splitData;

      if (customSplitAmounts != null && customSplitAmounts.isNotEmpty) {
        splitType = 'custom';
        splitData = customSplitAmounts;
      } else if (splitAmong != null && splitAmong.isNotEmpty) {
        splitType = 'equal';
        splitData = splitAmong;
      } else {
        throw 'Invalid split configuration. Must have splitAmong or customSplitAmounts.';
      }

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .add({
        'description': description,
        'amount': amount,
        'paidBy': paidBy,
        'expenseDate': Timestamp.fromDate(expenseDate),
        'notes': notes,
        'splitType': splitType,
        'splitData': splitData,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to add expense: \$e';
      notifyListeners();
    }
  }

  Future<Map<String, double>> calculateGroupBalances(
      String groupId, List<GroupMember> groupMembers) async {
    Map<String, double> balances = {};

    // Initialize balances for all group members to 0
    for (var member in groupMembers) {
      balances[member.userId] = 0.0;
    }

    final expenseSnapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .get();

    for (var doc in expenseSnapshot.docs) {
      final data = doc.data();
      final String paidBy = data['paidBy'];
      final double amount = (data['amount'] as num).toDouble();
      final String splitType = data['splitType'] ?? 'equal'; // Default to 'equal'

      // Add the full amount to the person who paid
      balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;

      if (splitType == 'equal') {
        final List<dynamic> splitAmong = data['splitAmong'] ?? [];
        if (splitAmong.isNotEmpty) {
          final double share = amount / splitAmong.length;
          for (var memberId in splitAmong) {
            balances[memberId.toString()] = (balances[memberId.toString()] ?? 0.0) - share;
          }
        }
      } else if (splitType == 'custom') {
        final Map<String, dynamic> customSplitAmounts = data['customSplitAmounts'] ?? {};
        customSplitAmounts.forEach((userId, customAmount) {
          balances[userId] = (balances[userId] ?? 0.0) - (customAmount as num).toDouble();
        });
      }
    }

    return balances;
  }

  Future<void> deleteGroup(String groupId, String userId) async {
    try {
      _setLoading(true);
      _error = null;

      // Get group data
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final group = GroupModel.fromFirestore(groupDoc);

      // Check if user is admin
      final user = group.members.firstWhere(
        (member) => member.userId == userId,
        orElse: () => throw 'You are not a member of this group',
      );

      if (!user.isAdmin) {
        throw 'Only group admins can delete the group';
      }

      // Delete all expenses
      final expensesSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .get();
      
      for (var doc in expensesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Remove group from all members' groupIds
      for (var member in group.members) {
        await _firestore.collection('users').doc(member.userId).update({
          'groupIds': FieldValue.arrayRemove([groupId]),
        });
      }

      // Delete the group document
      await _firestore.collection('groups').doc(groupId).delete();

      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _error = 'Failed to delete group: $e';
      notifyListeners();
    }
  }

  bool isUserAdmin(String userId, List<GroupMember> members) {
    return members.any((member) => member.userId == userId && member.isAdmin);
  }
} 