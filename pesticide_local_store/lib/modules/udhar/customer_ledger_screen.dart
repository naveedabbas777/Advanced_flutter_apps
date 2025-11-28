import 'package:flutter/material.dart';
import 'udhar_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CustomerLedgerScreen extends StatelessWidget {
  final String customerId;
  final String customerName;
  const CustomerLedgerScreen({
    Key? key,
    required this.customerId,
    required this.customerName,
  }) : super(key: key);

  Future<void> _printLedger(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String customerName,
    Map<String, dynamic> customerData,
  ) async {
    final pdf = pw.Document();
    final fatherName = customerData['fatherName'] ?? '';
    final phone1 = customerData['phone1'] ?? customerData['phone'] ?? '';
    final phone2 = customerData['phone2'] ?? '';
    final phone3 = customerData['phone3'] ?? '';
    final address = customerData['address'] ?? '';
    pdf.addPage(
      pw.MultiPage(
        build:
            (context) => [
              pw.Text(
                'Udhar Ledger',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Customer: $customerName'),
              pw.Text("Father's Name: $fatherName"),
              pw.Text('Phone: $phone1'),
              pw.Text('Address: $address'),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: ['Amount', 'Note', 'Date', 'Paid'],
                data:
                    docs.map((doc) {
                      final d = doc.data();
                      final amount = d['amount'] ?? 0;
                      final note = d['note'] ?? '';
                      final paid = d['paid'] ?? false;
                      final date = (d['date'] as Timestamp?)?.toDate();
                      return [
                        amount.toString(),
                        note,
                        date != null
                            ? DateFormat.yMMMd().add_jm().format(date)
                            : '',
                        paid ? 'Paid' : 'Unpaid',
                      ];
                    }).toList(),
              ),
            ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportCSV(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String customerName,
    Map<String, dynamic> customerData,
  ) async {
    final fatherName = customerData['fatherName'] ?? '';
    final phone1 = customerData['phone1'] ?? customerData['phone'] ?? '';
    final phone2 = customerData['phone2'] ?? '';
    final phone3 = customerData['phone3'] ?? '';
    final address = customerData['address'] ?? '';
    List<List<dynamic>> rows = [];
    rows.add(['Udhar Ledger']);
    rows.add(['Customer', customerName]);
    rows.add(["Father's Name", fatherName]);
    rows.add(['Phone', phone1]);
    rows.add(['Address', address]);
    rows.add([]);
    rows.add(['Amount', 'Note', 'Date', 'Paid']);
    for (var doc in docs) {
      final d = doc.data();
      final amount = d['amount'] ?? 0;
      final note = d['note'] ?? '';
      final paid = d['paid'] ?? false;
      final date = (d['date'] as Timestamp?)?.toDate();
      rows.add([
        amount.toString(),
        note,
        date != null ? DateFormat.yMMMd().add_jm().format(date) : '',
        paid ? 'Paid' : 'Unpaid',
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/udhar_ledger_${customerName.replaceAll(' ', '_')}.csv';
    final file = File(path);
    await file.writeAsString(csvData);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: 'udhar_ledger_${customerName.replaceAll(' ', '_')}.csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = UdharFirestoreService();
    final currency = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ');
    // Fetch customer data for phone numbers
    return FutureBuilder<DocumentSnapshot>(
      future: service.customers.doc(customerId).get(),
      builder: (context, customerSnap) {
        Map<String, dynamic> customerData = {};
        if (customerSnap.hasData && customerSnap.data != null) {
          customerData = customerSnap.data!.data() as Map<String, dynamic>;
        }
        final phone1 = customerData['phone1'] ?? customerData['phone'] ?? '';
        final phone2 = customerData['phone2'] ?? '';
        final phone3 = customerData['phone3'] ?? '';
        return Scaffold(
          appBar: AppBar(
            title: Text('Ledger: $customerName'),
            actions: [
              IconButton(
                icon: const Icon(Icons.phone),
                tooltip: 'Show all phone numbers',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Phone Numbers'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.phone),
                                title: Text(phone1),
                                onTap: () {
                                  Navigator.pop(context);
                                },
                              ),
                              if (phone2.isNotEmpty)
                                ListTile(
                                  leading: const Icon(Icons.phone),
                                  title: Text(phone2),
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                ),
                              if (phone3.isNotEmpty)
                                ListTile(
                                  leading: const Icon(Icons.phone),
                                  title: Text(phone3),
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  );
                },
              ),
              Builder(
                builder:
                    (context) => IconButton(
                      icon: const Icon(Icons.print),
                      tooltip: 'Print Ledger',
                      onPressed: () async {
                        final docs =
                            await service.getLedger(customerId).first
                                as QuerySnapshot<Map<String, dynamic>>;
                        await _printLedger(
                          docs.docs,
                          customerName,
                          customerData,
                        );
                      },
                    ),
              ),
              Builder(
                builder:
                    (context) => IconButton(
                      icon: const Icon(Icons.file_download),
                      tooltip: 'Export CSV',
                      onPressed: () async {
                        final docs =
                            await service.getLedger(customerId).first
                                as QuerySnapshot<Map<String, dynamic>>;
                        await _exportCSV(docs.docs, customerName, customerData);
                      },
                    ),
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
              child: StreamBuilder(
                stream: service.getLedger(customerId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs =
                      (snapshot.data as QuerySnapshot<Map<String, dynamic>>)
                          .docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No credit entries for this customer.'),
                    );
                  }
                  double runningBalance = 0;
                  double outstanding = 0;
                  double totalSales = 0;
                  double totalPayments = 0;
                  for (var doc in docs) {
                    final data = doc.data();
                    final amount = (data['amount'] ?? 0).toDouble();
                    outstanding += amount;
                    if (amount > 0) totalSales += amount;
                    if (amount < 0) totalPayments += -amount;
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Sales:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currency.format(totalSales),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total Payments:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currency.format(totalPayments),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Payable:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              currency.format(outstanding),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color:
                                    outstanding > 0
                                        ? Colors.red
                                        : (outstanding < 0
                                            ? Colors.green
                                            : Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final amount = (data['amount'] ?? 0).toDouble();
                            final note = data['note'] ?? '';
                            final date = (data['date'] as Timestamp?)?.toDate();
                            runningBalance += amount;
                            final isPayment = amount < 0;
                            final entryType = isPayment ? 'Payment' : 'Sale';
                            final entryColor =
                                isPayment ? Colors.green : Colors.red;
                            final entryIcon =
                                isPayment
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: Icon(entryIcon, color: entryColor),
                                title: Text(
                                  '$entryType: ${currency.format(amount.abs())}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: entryColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (note.isNotEmpty) Text(note),
                                    if (date != null)
                                      Text(
                                        DateFormat.yMMMd().add_jm().format(
                                          date,
                                        ),
                                      ),
                                    Text(
                                      'Remaining Udhar: ${currency.format(runningBalance)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            runningBalance > 0
                                                ? Colors.red
                                                : (runningBalance < 0
                                                    ? Colors.green
                                                    : Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
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
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final amountController = TextEditingController();
              final noteController = TextEditingController();
              // Get current outstanding
              double outstanding = 0;
              final docs =
                  await service.getLedger(customerId).first
                      as QuerySnapshot<Map<String, dynamic>>;
              for (var doc in docs.docs) {
                final data = doc.data();
                final amount = (data['amount'] ?? 0).toDouble();
                outstanding += amount;
              }
              final result = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Settle Up (Payment Received)'),
                      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Outstanding: ${currency.format(outstanding)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Payment Amount',
                            ),
                          ),
                          TextField(
                            controller: noteController,
                            decoration: const InputDecoration(
                              labelText: 'Note (optional)',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final amount =
                                double.tryParse(amountController.text) ?? 0;
                            if (amount > 0) {
                              await service.addCreditEntry(
                                customerId,
                                -amount, // Negative entry for payment
                                'Payment: ${noteController.text}',
                              );
                              Navigator.pop(context, true);
                            }
                          },
                          child: const Text('Settle Up'),
                        ),
                      ],
                    ),
              );
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment recorded.')),
                );
              }
            },
            child: const Icon(Icons.payments),
            tooltip: 'Settle Up (Payment)',
          ),
        );
      },
    );
  }
}
