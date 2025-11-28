import 'package:cloud_firestore/cloud_firestore.dart';

class UdharFirestoreService {
  final CollectionReference customers = FirebaseFirestore.instance.collection(
    'udhar_customers',
  );
  final CollectionReference ledgers = FirebaseFirestore.instance.collection(
    'udhar_ledgers',
  );

  Stream<QuerySnapshot> getCustomers() {
    return customers.orderBy('name').snapshots();
  }

  Stream<QuerySnapshot> getLedger(String customerId) {
    return ledgers
        .where('customerId', isEqualTo: customerId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> addCreditEntry(
    String customerId,
    double amount,
    String note,
  ) async {
    await ledgers.add({
      'customerId': customerId,
      'amount': amount,
      'note': note,
      'date': FieldValue.serverTimestamp(),
      'paid': false,
    });
  }

  Future<void> markAsPaid(String ledgerId) async {
    await ledgers.doc(ledgerId).update({'paid': true});
  }

  Future<DocumentReference> addCustomer({
    required String name,
    required String fatherName,
    required String phone1,
    String? phone2,
    String? phone3,
    String? address,
  }) async {
    return await customers.add({
      'name': name,
      'fatherName': fatherName,
      'phone1': phone1,
      'phone2': phone2,
      'phone3': phone3,
      'address': address,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
