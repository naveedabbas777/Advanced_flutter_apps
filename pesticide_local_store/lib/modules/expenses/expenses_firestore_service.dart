import 'package:cloud_firestore/cloud_firestore.dart';

class ExpensesFirestoreService {
  final CollectionReference _expenses = FirebaseFirestore.instance.collection(
    'expenses',
  );

  Stream<List<Expense>> getExpenses() {
    return _expenses
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => Expense.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  Future<void> addExpense(Expense expense) async {
    await _expenses.add(expense.toMap());
  }

  Future<void> updateExpense(Expense expense) async {
    await _expenses.doc(expense.id).update(expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    await _expenses.doc(id).delete();
  }
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final DateTime timestamp;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.timestamp,
  });

  factory Expense.fromMap(Map<String, dynamic> map, String id) {
    return Expense(
      id: id,
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
