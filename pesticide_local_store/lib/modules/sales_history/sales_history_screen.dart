import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sales_history_firestore_service.dart';
import 'sale_detail_screen.dart';
import 'daily_report_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _service = SalesHistoryFirestoreService();
  DateTime? _selectedDate;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2022),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by invoice ID, name, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.yellow[50],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _service.getSales(date: _selectedDate),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    double total = 0;
                    double naqad = 0;
                    double udhar = 0;
                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final saleType = data['saleType'] ?? '';
                      final saleTotal = (data['total'] ?? 0).toDouble();
                      total += saleTotal;
                      if (saleType == 'naqad') {
                        naqad += saleTotal;
                      } else {
                        udhar += saleTotal;
                      }
                    }
                    // Filter docs by search query
                    final filteredDocs =
                        _searchQuery.isEmpty
                            ? docs
                            : docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final customerName =
                                  (data['customerName'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              final customerPhone =
                                  (data['customerPhone'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              final invoiceId =
                                  (data['invoiceId'] ?? doc.id)
                                      .toString()
                                      .toLowerCase();
                              return invoiceId.contains(_searchQuery) ||
                                  customerName.contains(_searchQuery) ||
                                  customerPhone.contains(_searchQuery);
                            }).toList();
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Sales',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  Text(
                                    'Rs. $total',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Naqad: Rs. $naqad',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                  Text(
                                    'Udhar: Rs. $udhar',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child:
                              filteredDocs.isEmpty
                                  ? const Center(child: Text('No sales found.'))
                                  : ListView.builder(
                                    itemCount: filteredDocs.length,
                                    itemBuilder: (context, index) {
                                      final doc = filteredDocs[index];
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final customerName =
                                          data['customerName'] ?? '';
                                      final customerPhone =
                                          data['customerPhone'] ?? '';
                                      final invoiceId =
                                          data['invoiceId'] ?? doc.id;
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.receipt_long,
                                            color: Colors.deepPurple,
                                          ),
                                          title: Text(
                                            'Invoice: $invoiceId',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Total: Rs. ${data['total']}  |  Type: ${data['saleType']}',
                                              ),
                                              Text('Customer: $customerName'),
                                              Text('Phone: $customerPhone'),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.deepPurple,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) => SaleDetailScreen(
                                                        saleId: doc.id,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => SaleDetailScreen(
                                                      saleId: doc.id,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyReportScreen()),
          );
        },
        child: const Icon(Icons.bar_chart),
        tooltip: 'Daily Report',
      ),
    );
  }
}
