import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sales_history_firestore_service.dart';

class SaleDetailScreen extends StatelessWidget {
  final String saleId;
  const SaleDetailScreen({Key? key, required this.saleId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = SalesHistoryFirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Sale Details')),
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
          child: FutureBuilder<DocumentSnapshot>(
            future: service.getSaleById(saleId),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data == null)
                return const Center(child: Text('Sale not found.'));
              final items = List<Map<String, dynamic>>.from(
                data['items'] ?? [],
              );
              final date = (data['timestamp'] as Timestamp?)?.toDate();
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Invoice: $saleId',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (date != null) Text('Date: ${date.toLocal()}'),
                        Text('Customer: ${data['customerName'] ?? ''}'),
                        Text('Phone: ${data['customerPhone'] ?? ''}'),
                        Text('Type: ${data['saleType'] ?? ''}'),
                        const SizedBox(height: 16),
                        const Text(
                          'Items:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...items.map(
                          (item) => ListTile(
                            title: Text(item['name'] ?? ''),
                            subtitle: Text(
                              'Qty: ${item['quantity']} x Rs. ${item['price']}',
                            ),
                            trailing: Text(
                              'Rs. ${item['quantity'] * item['price']}',
                            ),
                          ),
                        ),
                        const Divider(),
                        Text(
                          'Total: Rs. ${data['total'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.print),
                              label: const Text('Print'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.file_download),
                              label: const Text('Export'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
