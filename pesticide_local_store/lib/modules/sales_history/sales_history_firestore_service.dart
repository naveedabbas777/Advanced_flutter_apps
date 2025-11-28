import 'package:cloud_firestore/cloud_firestore.dart';

class SalesHistoryFirestoreService {
  final CollectionReference _sales = FirebaseFirestore.instance.collection(
    'sales',
  );

  Stream<QuerySnapshot> getSales({DateTime? date}) {
    Query query = _sales.orderBy('timestamp', descending: true);
    if (date != null) {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: start,
        isLessThan: end,
      );
    }
    return query.snapshots();
  }

  Future<DocumentSnapshot> getSaleById(String id) async {
    return await _sales.doc(id).get();
  }
}
