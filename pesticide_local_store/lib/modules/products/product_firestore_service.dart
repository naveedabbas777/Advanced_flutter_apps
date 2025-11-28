import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_model.dart';

class ProductFirestoreService {
  final CollectionReference _products = FirebaseFirestore.instance.collection(
    'products',
  );

  Stream<List<Product>> getProducts() {
    return _products.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map(
                (doc) =>
                    Product.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList(),
    );
  }

  Future<void> addProduct(Product product) async {
    await _products.add(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _products.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _products.doc(id).delete();
  }

  // Update stock quantity for a product
  Future<void> updateStockQuantity(String productId, int newQuantity) async {
    await _products.doc(productId).update({'quantity': newQuantity});
  }

  // Decrease stock quantity by sold amount
  Future<void> decreaseStockQuantity(String productId, int soldQuantity) async {
    final doc = await _products.doc(productId).get();
    if (doc.exists) {
      final currentStock =
          (doc.data() as Map<String, dynamic>)['quantity'] ?? 0;
      final newStock = currentStock - soldQuantity;
      if (newStock >= 0) {
        await _products.doc(productId).update({'quantity': newStock});
      }
    }
  }

  // Get current stock for a product
  Future<int> getCurrentStock(String productId) async {
    final doc = await _products.doc(productId).get();
    if (doc.exists) {
      return (doc.data() as Map<String, dynamic>)['quantity'] ?? 0;
    }
    return 0;
  }
}
