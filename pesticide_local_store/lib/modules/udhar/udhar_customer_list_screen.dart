import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'udhar_firestore_service.dart';
import 'customer_ledger_screen.dart';

class UdharCustomerListScreen extends StatefulWidget {
  const UdharCustomerListScreen({Key? key}) : super(key: key);

  @override
  State<UdharCustomerListScreen> createState() =>
      _UdharCustomerListScreenState();
}

class _UdharCustomerListScreenState extends State<UdharCustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = UdharFirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Udhar Customers')),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name, phone, or father\'s name',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: service.getCustomers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs =
                        (snapshot.data as QuerySnapshot<Map<String, dynamic>>)
                            .docs;
                    final filteredDocs =
                        _searchQuery.isEmpty
                            ? docs
                            : docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name =
                                  (data['name'] ?? '').toString().toLowerCase();
                              final phone =
                                  (data['phone'] ?? data['phone1'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              final fatherName =
                                  (data['fatherName'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              return name.contains(_searchQuery) ||
                                  phone.contains(_searchQuery) ||
                                  fatherName.contains(_searchQuery);
                            }).toList();
                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text('No Udhar customers found.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data =
                            filteredDocs[index].data() as Map<String, dynamic>;
                        final name = data['name'] ?? '';
                        final phone = data['phone'] ?? data['phone1'] ?? '';
                        final fatherName = data['fatherName'] ?? '';
                        final address = data['address'] ?? '';
                        final id = filteredDocs[index].id;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: service.getLedger(id),
                            builder: (context, ledgerSnapshot) {
                              double outstanding = 0;
                              if (ledgerSnapshot.hasData) {
                                final ledgerDocs = ledgerSnapshot.data!.docs;
                                for (var doc in ledgerDocs) {
                                  final entry =
                                      doc.data() as Map<String, dynamic>;
                                  final amount =
                                      (entry['amount'] ?? 0).toDouble();
                                  outstanding += amount;
                                }
                              }
                              return ListTile(
                                leading: const Icon(
                                  Icons.account_circle,
                                  color: Colors.deepPurple,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Father: $fatherName'),
                                    Text('Phone: $phone'),
                                    Text('Address: $address'),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Total Payable: Rs. ${outstanding.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            outstanding > 0
                                                ? Colors
                                                    .red // Sale (customer owes you)
                                                : (outstanding < 0
                                                    ? Colors
                                                        .green // Payment (customer overpaid)
                                                    : Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.deepPurple,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => CustomerLedgerScreen(
                                            customerId: id,
                                            customerName: name,
                                          ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final nameController = TextEditingController();
          final fatherNameController = TextEditingController();
          final phone1Controller = TextEditingController();
          final phone2Controller = TextEditingController();
          final phone3Controller = TextEditingController();
          final addressController = TextEditingController();
          // Address is now required
          final result = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Add Udhar Customer'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                          ),
                        ),
                        TextField(
                          controller: fatherNameController,
                          decoration: const InputDecoration(
                            labelText: "Father's Name *",
                          ),
                        ),
                        TextField(
                          controller: phone1Controller,
                          decoration: const InputDecoration(
                            labelText: 'Phone 1 *',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        TextField(
                          controller: phone2Controller,
                          decoration: const InputDecoration(
                            labelText: 'Phone 2 (optional)',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        TextField(
                          controller: phone3Controller,
                          decoration: const InputDecoration(
                            labelText: 'Phone 3 (optional)',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        TextField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address *',
                          ),
                          keyboardType: TextInputType.multiline,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final fatherName = fatherNameController.text.trim();
                        final phone1 = phone1Controller.text.trim();
                        final phone2 = phone2Controller.text.trim();
                        final phone3 = phone3Controller.text.trim();
                        final address = addressController.text.trim();
                        if (name.isNotEmpty &&
                            fatherName.isNotEmpty &&
                            phone1.isNotEmpty &&
                            address.isNotEmpty) {
                          await service.addCustomer(
                            name: name,
                            fatherName: fatherName,
                            phone1: phone1,
                            phone2: phone2.isNotEmpty ? phone2 : null,
                            phone3: phone3.isNotEmpty ? phone3 : null,
                            address: address,
                          );
                          Navigator.pop(context, true);
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
          );
          if (result == true) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Customer added.')));
          }
        },
        child: const Icon(Icons.person_add),
        tooltip: 'Add Customer',
      ),
    );
  }
}
