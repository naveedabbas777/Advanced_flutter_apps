import 'package:flutter/material.dart';
import '../products/product_firestore_service.dart';
import '../products/product_model.dart';

class ExpiryAlertsScreen extends StatelessWidget {
  const ExpiryAlertsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = ProductFirestoreService();
    final expiryThreshold = DateTime.now().add(const Duration(days: 30));
    return Scaffold(
      appBar: AppBar(title: const Text('Expiry Alerts')),
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
              final expiryAlerts =
                  products.where((p) {
                    try {
                      return p.expiryDate != null &&
                          p.expiryDate.isBefore(expiryThreshold);
                    } catch (_) {
                      return false;
                    }
                  }).toList();
              if (expiryAlerts.isEmpty) {
                return const Center(child: Text('No products nearing expiry.'));
              }
              return ListView.builder(
                itemCount: expiryAlerts.length,
                itemBuilder: (context, index) {
                  final product = expiryAlerts[index];
                  return Card(
                    color: Colors.orange[50],
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.timer,
                        color: Colors.deepOrange,
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Expiry: ${product.expiryDate != null ? product.expiryDate.toLocal().toString().split(' ')[0] : 'N/A'}',
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
