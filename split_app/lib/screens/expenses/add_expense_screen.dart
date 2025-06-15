import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  AddExpenseScreen({required this.groupId, required this.groupName});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedPaidBy;
  List<String> _selectedSplitAmong = [];
  List<Map<String, String>> _members = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchGroupMembers();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroupMembers() async {
    setState(() => _isLoading = true);
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (membersSnapshot.exists) {
        List<String> memberIds = List<String>.from(membersSnapshot.data()?['members'] ?? []);
        List<Map<String, String>> fetchedMembers = [];

        for (String memberId in memberIds) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            fetchedMembers.add({
              'id': userDoc.id,
              'name': userDoc.data()?['name'] ?? userDoc.data()?['email'] ?? 'Unknown',
            });
          }
        }
        setState(() {
          _members = fetchedMembers;
          _selectedPaidBy = fetchedMembers.isNotEmpty ? fetchedMembers.first['id'] : null;
          _selectedSplitAmong = fetchedMembers.map((e) => e['id']!).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch members: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addExpense() async {
    if (_formKey.currentState!.validate() &&
        _selectedPaidBy != null &&
        _selectedSplitAmong.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await context.read<GroupProvider>().addExpense(
              groupId: widget.groupId,
              description: _descriptionController.text.trim(),
              amount: double.parse(_amountController.text.trim()),
              paidBy: _selectedPaidBy!,
              splitAmong: _selectedSplitAmong,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Expense added successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = Provider.of<GroupProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense to ${widget.groupName}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Expense Details',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Paid By',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      value: _selectedPaidBy,
                      items: _members.map((member) {
                        return DropdownMenuItem(
                          value: member['id'],
                          child: Text(member['name']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaidBy = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select who paid';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Split Among',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.people_outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8.0,
                            children: _members.map((member) {
                              final isSelected = _selectedSplitAmong.contains(member['id']);
                              return FilterChip(
                                label: Text(member['name']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSplitAmong.add(member['id']!);
                                    } else {
                                      _selectedSplitAmong.remove(member['id']!);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          if (_selectedSplitAmong.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Please select at least one member.',
                                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: groupProvider.isLoading ? null : _addExpense,
                      child: groupProvider.isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Add Expense'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 