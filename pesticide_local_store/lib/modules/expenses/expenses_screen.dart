import 'package:flutter/material.dart';
import 'expenses_firestore_service.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _service = ExpensesFirestoreService();
  String _filterQuery = '';
  DateTime? _filterDate;

  Future<void> _addExpense() async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    final result = await showDialog<Expense>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final desc = descController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (desc.isNotEmpty && amount > 0) {
                    Navigator.pop(
                      context,
                      Expense(
                        id: '',
                        description: desc,
                        amount: amount,
                        timestamp: DateTime.now(),
                      ),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
    if (result != null) {
      await _service.addExpense(result);
    }
  }

  void _showEditDeleteDialog(Expense expense) async {
    final descController = TextEditingController(text: expense.description);
    final amountController = TextEditingController(
      text: expense.amount.toString(),
    );
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit or Delete Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final desc = descController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (desc.isNotEmpty && amount > 0) {
                    _service.updateExpense(
                      Expense(
                        id: expense.id,
                        description: desc,
                        amount: amount,
                        timestamp: expense.timestamp,
                      ),
                    );
                    Navigator.pop(context, 'edit');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (result == 'delete') {
      await _service.deleteExpense(expense.id);
    }
  }

  List<Expense> _applyFilters(List<Expense> expenses) {
    return expenses.where((e) {
      final matchesDesc =
          _filterQuery.isEmpty ||
          e.description.toLowerCase().contains(_filterQuery.toLowerCase());
      final matchesDate =
          _filterDate == null ||
          (e.timestamp.year == _filterDate!.year &&
              e.timestamp.month == _filterDate!.month &&
              e.timestamp.day == _filterDate!.day);
      return matchesDesc && matchesDate;
    }).toList();
  }

  Future<void> _exportToCSV(List<Expense> expenses) async {
    final rows = [
      ['Description', 'Amount', 'Date'],
      ...expenses.map(
        (e) => [
          e.description,
          e.amount.toStringAsFixed(2),
          e.timestamp.toLocal().toString().split(' ')[0],
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/expenses_export_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Export Successful'),
              content: Text('Exported to:\n${file.path}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () {
                    Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'Shop Expenses Export');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          StreamBuilder<List<Expense>>(
            stream: _service.getExpenses(),
            builder: (context, snapshot) {
              final expenses = _applyFilters(snapshot.data ?? []);
              return IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                tooltip: 'Export to CSV',
                onPressed:
                    expenses.isEmpty ? null : () => _exportToCSV(expenses),
              );
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter by description...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.deepPurple,
                        ),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                      ),
                      onChanged: (v) => setState(() => _filterQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Colors.deepPurple,
                    ),
                    tooltip: 'Filter by date',
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      setState(() => _filterDate = picked);
                    },
                  ),
                  if (_filterDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      tooltip: 'Clear date filter',
                      onPressed: () => setState(() => _filterDate = null),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Expenses:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  StreamBuilder<List<Expense>>(
                    stream: _service.getExpenses(),
                    builder: (context, snapshot) {
                      final expenses = _applyFilters(snapshot.data ?? []);
                      final total = expenses.fold(
                        0.0,
                        (sum, e) => sum + e.amount,
                      );
                      return Text(
                        'Rs. ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<Expense>>(
                stream: _service.getExpenses(),
                builder: (context, snapshot) {
                  final expenses = _applyFilters(snapshot.data ?? []);
                  if (expenses.isEmpty) {
                    return const Center(
                      child: Text(
                        'No expenses recorded yet.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.deepPurple,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final e = expenses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.money_off,
                            color: Colors.red,
                          ),
                          title: Text(
                            e.description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${e.timestamp.toLocal().toString().split(' ')[0]}',
                          ),
                          trailing: Text(
                            'Rs. ${e.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          onTap: () => _showEditDeleteDialog(e),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add),
        tooltip: 'Add Expense',
      ),
    );
  }
}
