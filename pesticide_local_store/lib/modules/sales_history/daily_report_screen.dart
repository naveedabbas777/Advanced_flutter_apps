import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sales_history_firestore_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ProductSummary {
  final String name;
  int quantity;
  double total;
  ProductSummary({required this.name, this.quantity = 0, this.total = 0.0});
}

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({Key? key}) : super(key: key);

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final _service = SalesHistoryFirestoreService();
  DateTime _selectedDate = DateTime.now();

  // Helper functions for robust type conversion from Firestore
  T getField<T>(dynamic value, {T? defaultValue}) {
    if (value == null) return defaultValue ?? (T == int ? 0 : 0.0) as T;
    if (T == int) {
      if (value is int) return value as T;
      if (value is double) return value.toInt() as T;
      if (value is String)
        return int.tryParse(value) as T? ?? (defaultValue ?? 0 as T);
    }
    if (T == double) {
      if (value is double) return value as T;
      if (value is int) return value.toDouble() as T;
      if (value is String)
        return double.tryParse(value) as T? ?? (defaultValue ?? 0.0 as T);
    }
    return defaultValue ?? (T == int ? 0 : 0.0) as T;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2022),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
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
          child: StreamBuilder<QuerySnapshot>(
            stream: _service.getSales(date: _selectedDate),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final salesData =
                  snapshot.data?.docs.map((doc) => doc.data()).toList() ?? [];
              final sales = List<Map<String, dynamic>>.from(salesData);

              double total = 0.0;
              double cash = 0.0;
              double credit = 0.0;
              List<ProductSummary> productSummary = [];

              if (sales.isNotEmpty) {
                total = sales.fold(
                  0.0,
                  (sum, sale) =>
                      sum + getField<double>(sale['total'], defaultValue: 0.0),
                );
                cash = sales.fold(
                  0.0,
                  (sum, sale) =>
                      sum + getField<double>(sale['cash'], defaultValue: 0.0),
                );
                credit = sales.fold(
                  0.0,
                  (sum, sale) =>
                      sum + getField<double>(sale['credit'], defaultValue: 0.0),
                );

                final productMap = <String, ProductSummary>{};
                for (var sale in sales) {
                  final invoiceId = sale['invoiceId']?.toString() ?? '';
                  final customerName = sale['customerName']?.toString() ?? '';
                  final saleType = sale['saleType']?.toString() ?? '';
                  final quantity = getField<int>(
                    sale['quantity'],
                    defaultValue: 0,
                  );
                  final price = getField<double>(
                    sale['price'],
                    defaultValue: 0.0,
                  );
                  final productName = sale['productName']?.toString() ?? '';

                  if (productMap.containsKey(productName)) {
                    productMap[productName]!.quantity += quantity;
                    productMap[productName]!.total += quantity * price;
                  } else {
                    productMap[productName] = ProductSummary(
                      name: productName,
                      quantity: quantity,
                      total: quantity * price,
                    );
                  }
                }
                productSummary = productMap.values.toList();
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.deepPurple[50],
                        child: ListTile(
                          title: Text(
                            'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Total Sales: Rs. $total',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cash: Rs. $cash',
                                style: const TextStyle(color: Colors.green),
                              ),
                              Text(
                                'Credit: Rs. $credit',
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _printReport(
                                total,
                                cash,
                                credit,
                                sales,
                                productSummary,
                              );
                            },
                            icon: const Icon(Icons.print),
                            label: const Text('Print Report'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _exportCSV(
                                total,
                                cash,
                                credit,
                                sales,
                                productSummary,
                              );
                            },
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export CSV'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sales List',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      sales.isEmpty
                          ? const Text('No sales for this day.')
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sales.length,
                            itemBuilder: (context, idx) {
                              final sale = sales[idx];
                              final s =
                                  sale is Map<String, dynamic>
                                      ? sale
                                      : <String, dynamic>{};
                              final invoiceId =
                                  s['invoiceId']?.toString() ?? '';
                              final customerName =
                                  s['customerName']?.toString() ?? '';
                              final total = getField<double>(
                                s['total'],
                                defaultValue: 0.0,
                              );
                              final saleType =
                                  s['saleType'] == 'naqad'
                                      ? 'Cash'
                                      : (s['saleType'] == 'udhar'
                                          ? 'Credit'
                                          : s['saleType']);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.receipt_long,
                                    color: Colors.deepPurple,
                                  ),
                                  title: Text('Invoice: $invoiceId'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Customer: $customerName'),
                                      Text(
                                        'Total: Rs. $total  |  Type: $saleType',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      const SizedBox(height: 24),
                      Text(
                        'Per-Product Summary',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      productSummary.isEmpty
                          ? const Text('No product sales for this day.')
                          : ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children:
                                productSummary.map((prod) {
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.shopping_bag,
                                        color: Colors.yellow,
                                      ),
                                      title: Text(prod.name),
                                      subtitle: Text(
                                        'Qty:  ${prod.quantity}  |  Total: Rs. ${prod.total}',
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _printReport(
    double total,
    double cash,
    double credit,
    List<Map<String, dynamic>> sales,
    List<ProductSummary> productSummary,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build:
            (context) => [
              pw.Text(
                'Daily Sales Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
              ),
              pw.SizedBox(height: 8),
              pw.Text('Total Sales: Rs. $total'),
              pw.Text('Cash: Rs. $cash'),
              pw.Text('Credit: Rs. $credit'),
              pw.SizedBox(height: 16),
              pw.Text(
                'Sales List',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              if (sales.isEmpty)
                pw.Text('No sales for this day.')
              else
                pw.Table.fromTextArray(
                  headers: ['Invoice', 'Customer', 'Total', 'Type'],
                  data:
                      sales
                          .map(
                            (s) => [
                              s['invoiceId'],
                              s['customerName'],
                              s['total'].toString(),
                              s['saleType'],
                            ],
                          )
                          .toList(),
                ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Per-Product Summary',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              if (productSummary.isEmpty)
                pw.Text('No product sales for this day.')
              else
                pw.Table.fromTextArray(
                  headers: ['Product', 'Qty', 'Total'],
                  data:
                      productSummary.map((prod) {
                        return [
                          prod.name,
                          prod.quantity.toString(),
                          prod.total.toString(),
                        ];
                      }).toList(),
                ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportCSV(
    double total,
    double cash,
    double credit,
    List<Map<String, dynamic>> sales,
    List<ProductSummary> productSummary,
  ) async {
    List<List<dynamic>> rows = [];
    rows.add(['Daily Sales Report']);
    rows.add(['Date', _selectedDate.toLocal().toString().split(' ')[0]]);
    rows.add(['Total Sales', total]);
    rows.add(['Cash', cash]);
    rows.add(['Credit', credit]);
    rows.add([]);
    rows.add(['Sales List']);
    rows.add(['Invoice', 'Customer', 'Total', 'Type']);
    for (var s in sales) {
      rows.add([s['invoiceId'], s['customerName'], s['total'], s['saleType']]);
    }
    rows.add([]);
    rows.add(['Per-Product Summary']);
    rows.add(['Product', 'Qty', 'Total']);
    for (var prod in productSummary) {
      rows.add([prod.name, prod.quantity, prod.total]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/daily_report_${_selectedDate.toLocal().toString().split(' ')[0]}.csv';
    final file = File(path);
    await file.writeAsString(csvData);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename:
          'daily_report_${_selectedDate.toLocal().toString().split(' ')[0]}.csv',
    );
  }
}
