import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add new expense
  Future<void> addExpense({
    required String groupId,
    required String title,
    required double amount,
    required String paidBy,
    String? notes,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .add({
        'title': title,
        'amount': amount,
        'paidBy': paidBy,
        'date': FieldValue.serverTimestamp(),
        'notes': notes,
        'createdBy': _auth.currentUser!.uid,
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // Update expense
  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required String paidBy,
    String? notes,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .update({
        'title': title,
        'amount': amount,
        'paidBy': paidBy,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // Delete expense
  Future<void> deleteExpense(String groupId, String expenseId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .delete();
    } catch (e) {
      throw e.toString();
    }
  }

  // Get expense details
  Future<DocumentSnapshot> getExpenseDetails(
      String groupId, String expenseId) async {
    return await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .get();
  }

  // Get total expenses for a group
  Future<double> getTotalExpenses(String groupId) async {
    try {
      QuerySnapshot expensesSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .get();

      double total = 0;
      for (var expense in expensesSnapshot.docs) {
        total += expense['amount'];
      }
      return total;
    } catch (e) {
      throw e.toString();
    }
  }

  // Get user's share in a group
  Future<double> getUserShare(String groupId) async {
    try {
      DocumentSnapshot groupDoc =
          await _firestore.collection('groups').doc(groupId).get();
      List<dynamic> members = groupDoc['members'];
      double totalExpenses = await getTotalExpenses(groupId);
      return totalExpenses / members.length;
    } catch (e) {
      throw e.toString();
    }
  }

  // Export expenses to CSV
  Future<String> exportExpensesToCSV(String groupId) async {
    try {
      QuerySnapshot expensesSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      String csv = 'Date,Title,Amount,Paid By,Notes\n';
      for (var expense in expensesSnapshot.docs) {
        DateTime date = (expense['date'] as Timestamp).toDate();
        csv += '${date.toString()},${expense['title']},${expense['amount']},${expense['paidBy']},${expense['notes'] ?? ""}\n';
      }
      return csv;
    } catch (e) {
      throw e.toString();
    }
  }
} 