import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new group
  Future<String> createGroup(String name, double initialAmount) async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentReference groupRef = await _firestore.collection('groups').add({
        'name': name,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'members': [userId],
        'initialAmount': initialAmount,
        'expenses': [],
      });

      // Add group to user's groups
      await _firestore.collection('users').doc(userId).update({
        'groups': FieldValue.arrayUnion([groupRef.id])
      });

      return groupRef.id;
    } catch (e) {
      throw e.toString();
    }
  }

  // Get all groups for current user
  Stream<List<DocumentSnapshot>> getUserGroups() {
    String userId = _auth.currentUser!.uid;
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Get group details
  Future<DocumentSnapshot> getGroupDetails(String groupId) async {
    return await _firestore.collection('groups').doc(groupId).get();
  }

  // Add member to group
  Future<void> addMemberToGroup(String groupId, String userEmail) async {
    try {
      // Find user by email
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        throw 'User not found';
      }

      String userId = userQuery.docs.first.id;

      // Add user to group
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      // Add group to user's groups
      await _firestore.collection('users').doc(userId).update({
        'groups': FieldValue.arrayUnion([groupId])
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // Remove member from group
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    try {
      // Remove user from group
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
        'memberIds': FieldValue.arrayRemove([userId]),
      });

      // Remove group from user's groups
      await _firestore.collection('users').doc(userId).update({
        'groups': FieldValue.arrayRemove([groupId])
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // Get group expenses
  Stream<List<DocumentSnapshot>> getGroupExpenses(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Calculate group balances
  Future<Map<String, double>> calculateGroupBalances(String groupId) async {
    try {
      DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(groupId).get();
      List<dynamic> members = groupDoc['members'];
      double initialAmount = groupDoc['initialAmount'] ?? 0.0;
      
      // Get all expenses
      QuerySnapshot expensesSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .get();

      Map<String, double> balances = {};
      for (String memberId in members) {
        balances[memberId] = -initialAmount; // Start with negative initial amount
      }

      // Calculate balances
      for (var expense in expensesSnapshot.docs) {
        String paidBy = expense['paidBy'];
        double amount = expense['amount'];
        int memberCount = members.length;
        double sharePerMember = amount / memberCount;

        // Add full amount to payer
        balances[paidBy] = (balances[paidBy] ?? 0) + amount;

        // Subtract share from each member
        for (String memberId in members) {
          balances[memberId] = (balances[memberId] ?? 0) - sharePerMember;
        }
      }

      return balances;
    } catch (e) {
      throw e.toString();
    }
  }
} 