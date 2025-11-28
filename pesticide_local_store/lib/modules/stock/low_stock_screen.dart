import 'package:flutter/material.dart';
import '../products/product_firestore_service.dart';
import '../products/product_model.dart';

class LowStockScreen extends StatelessWidget {
  const LowStockScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = ProductFirestoreService();
    const lowStockThreshold = 10;
    return Scaffold(
      appBar: AppBar(title: const Text('Low Stock Alerts')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<Product>>(
            stream: service.getProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data ?? [];
              final lowStock =
                  products
                      .where((p) => (p.quantity) < lowStockThreshold)
                      .toList();
              if (lowStock.isEmpty) {
                return const Center(child: Text('No low stock products.'));
              }
              return ListView.builder(
                itemCount: lowStock.length,
                itemBuilder: (context, index) {
                  final product = lowStock[index];
                  return Card(
                    color: Colors.red[50],
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.warning, color: Colors.red),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Stock: ${product.quantity} ${product.unit}',
                      ),
                      // Removed trailing edit icon
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
