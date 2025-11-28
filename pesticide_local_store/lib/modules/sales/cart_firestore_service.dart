import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'cart_model.dart';
import '../products/product_firestore_service.dart';

class CartFirestoreService {
  final CollectionReference _sales = FirebaseFirestore.instance.collection(
    'sales',
  );
  final ProductFirestoreService _productService = ProductFirestoreService();

  String _generateInvoiceId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(
      11,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  // Validate stock availability before sale
  Future<bool> validateStock(Cart cart) async {
    for (var item in cart.items) {
      final currentStock = await _productService.getCurrentStock(
        item.product.id,
      );
      if (currentStock < item.quantity) {
        return false; // Insufficient stock
      }
    }
    return true; // All items have sufficient stock
  }

  Future<String> addSale(Cart cart) async {
    // Validate stock before processing sale
    final hasStock = await validateStock(cart);
    if (!hasStock) {
      throw Exception('Insufficient stock for one or more products');
    }

    final invoiceId = _generateInvoiceId();

    // Use a batch to ensure atomic operations
    final batch = FirebaseFirestore.instance.batch();

    // Add sale record
    final saleRef = _sales.doc();
    batch.set(saleRef, {
      'invoiceId': invoiceId,
      'items':
          cart.items
              .map(
                (item) => {
                  'productId': item.product.id,
                  'name': item.product.name,
                  'quantity': item.quantity,
                  'price': item.product.salePrice,
                  'remainingStock':
                      item.product.quantity -
                      item.quantity, // Show remaining stock
                },
              )
              .toList(),
      'saleType': cart.saleType.toString().split('.').last,
      'customerName': cart.customerName,
      'customerPhone': cart.customerPhone,
      'total': cart.totalPrice,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update stock for each product
    for (var item in cart.items) {
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(item.product.id);

      // Get current stock and update
      final productDoc = await productRef.get();
      if (productDoc.exists) {
        final currentStock =
            (productDoc.data() as Map<String, dynamic>)['quantity'] ?? 0;
        final newStock = currentStock - item.quantity;
        if (newStock >= 0) {
          batch.update(productRef, {'quantity': newStock});
        }
      }
    }

    // Commit all changes atomically
    await batch.commit();

    return invoiceId;
  }

  Stream<QuerySnapshot> getSales() {
    return _sales.orderBy('timestamp', descending: true).snapshots();
  }
}
