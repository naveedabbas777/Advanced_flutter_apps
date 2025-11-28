import 'package:flutter/material.dart';

class ExportPrintScreen extends StatelessWidget {
  const ExportPrintScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export & Print')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.file_download,
                color: Colors.deepPurple,
              ),
              title: const Text(
                'Export CSV',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt, color: Colors.deepPurple),
              title: const Text(
                'Print Invoice',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.print, color: Colors.deepPurple),
              title: const Text(
                'Print Daily Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.account_balance_wallet,
                color: Colors.deepPurple,
              ),
              title: const Text(
                'Print Udhar Ledger',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
