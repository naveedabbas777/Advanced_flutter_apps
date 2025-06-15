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

enum SplitType { equal, custom }

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedPaidBy;
  List<String> _selectedSplitAmong = [];
  List<Map<String, String>> _members = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  SplitType _splitType = SplitType.equal;
  Map<String, TextEditingController> _customSplitControllers = {};
  Map<String, double> _customSplitAmounts = {};

  @override
  void initState() {
    super.initState();
    _fetchGroupMembers();
    _amountController.addListener(_updateCustomSplitDefaultAmounts);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.removeListener(_updateCustomSplitDefaultAmounts);
    _amountController.dispose();
    _notesController.dispose();
    _customSplitControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _updateCustomSplitDefaultAmounts() {
    if (_splitType == SplitType.equal) return;

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final numSelectedMembers = _selectedSplitAmong.length;
    final equalShare = numSelectedMembers > 0 ? totalAmount / numSelectedMembers : 0.0;

    setState(() {
      _selectedSplitAmong.forEach((memberId) {
        _customSplitAmounts[memberId] = equalShare;
        _customSplitControllers[memberId]?.text = equalShare.toStringAsFixed(2);
      });
    });
  }

  Future<void> _fetchGroupMembers() async {
    setState(() => _isLoading = true);
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (membersSnapshot.exists) {
        final List<dynamic> rawMembers = membersSnapshot.data()?['members'] ?? [];
        List<Map<String, String>> fetchedMembers = [];

        _customSplitControllers = {};
        _customSplitAmounts = {};

        for (var memberData in rawMembers) {
          if (memberData is Map<String, dynamic>) {
            final userId = memberData['userId']?.toString() ?? '';
            final username = memberData['username']?.toString() ?? memberData['email']?.toString() ?? 'Unknown';
            if (userId.isNotEmpty) {
              fetchedMembers.add({
                'id': userId,
                'name': username,
              });
              _customSplitControllers[userId] = TextEditingController(text: '0.00');
              _customSplitAmounts[userId] = 0.0;
            }
          } else if (memberData is String) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberData).get();
            if (userDoc.exists) {
              final userId = userDoc.id;
              final username = userDoc.data()?['username'] ?? userDoc.data()?['email'] ?? 'Unknown';
              if (userId.isNotEmpty) {
                fetchedMembers.add({
                  'id': userId,
                  'name': username,
                });
                _customSplitControllers[userId] = TextEditingController(text: '0.00');
                _customSplitAmounts[userId] = 0.0;
              }
            }
          }
        }

        setState(() {
          _members = fetchedMembers;
          _selectedPaidBy = fetchedMembers.isNotEmpty ? fetchedMembers.first['id'] : null;
          _selectedSplitAmong = fetchedMembers.map((e) => e['id']!).toList();
          _updateCustomSplitDefaultAmounts();
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _validateCustomSplit() {
    if (_splitType == SplitType.equal) return true;

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    double sumOfCustomAmounts = 0.0;

    _selectedSplitAmong.forEach((memberId) {
      final amountText = _customSplitControllers[memberId]?.text;
      final customAmount = double.tryParse(amountText ?? '0') ?? 0.0;
      sumOfCustomAmounts += customAmount;
    });

    if (sumOfCustomAmounts.toStringAsFixed(2) != totalAmount.toStringAsFixed(2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sum of custom amounts must match total expense amount.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _addExpense() async {
    if (_formKey.currentState!.validate() &&
        _selectedPaidBy != null &&
        _selectedSplitAmong.isNotEmpty &&
        _validateCustomSplit()) {
      setState(() => _isLoading = true);
      try {
        await context.read<GroupProvider>().addExpense(
              groupId: widget.groupId,
              description: _descriptionController.text.trim(),
              amount: double.parse(_amountController.text.trim()),
              paidBy: _selectedPaidBy!,
              splitAmong: _splitType == SplitType.equal ? _selectedSplitAmong : null,
              customSplitAmounts: _splitType == SplitType.custom ? _customSplitAmounts : null,
              expenseDate: _selectedDate,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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
                        labelText: 'Title (e.g., Dinner)',
                        hintText: 'Enter expense title',
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Enter expense amount',
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
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: TextEditingController(text: "${_selectedDate.toLocal().day}/${_selectedDate.toLocal().month}/${_selectedDate.toLocal().year}"),
                          decoration: InputDecoration(
                            labelText: 'Date',
                            hintText: 'Select expense date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          validator: (value) {
                            if (_selectedDate == null) {
                              return 'Please select a date';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add any additional notes',
                        prefixIcon: Icon(Icons.note_alt),
                      ),
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
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
                    Center(
                      child: ToggleButtons(
                        isSelected: _splitType == SplitType.equal ? [true, false] : [false, true],
                        onPressed: (int index) {
                          setState(() {
                            _splitType = index == 0 ? SplitType.equal : SplitType.custom;
                            if (_splitType == SplitType.custom) {
                              _updateCustomSplitDefaultAmounts();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8.0),
                        selectedColor: Theme.of(context).colorScheme.onPrimary,
                        fillColor: Theme.of(context).colorScheme.primary,
                        color: Theme.of(context).colorScheme.primary,
                        borderColor: Theme.of(context).colorScheme.primary,
                        selectedBorderColor: Theme.of(context).colorScheme.primary,
                        children: const <Widget>[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Equal Split'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Custom Split'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    _splitType == SplitType.equal
                        ? InputDecorator(
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
                                            final currentAmount = double.tryParse(_amountController.text) ?? 0.0;
                                            _customSplitAmounts[member['id']!] = currentAmount / _selectedSplitAmong.length;
                                            _customSplitControllers[member['id']]?.text = (currentAmount / _selectedSplitAmong.length).toStringAsFixed(2);
                                          } else {
                                            _selectedSplitAmong.remove(member['id']!);
                                            _customSplitAmounts.remove(member['id']!);
                                            _customSplitControllers[member['id']]?.dispose();
                                            _customSplitControllers.remove(member['id']!);
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
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom Split Amounts',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ..._selectedSplitAmong.map((memberId) {
                                final member = _members.firstWhere((m) => m['id'] == memberId);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: TextFormField(
                                    controller: _customSplitControllers[memberId],
                                    decoration: InputDecoration(
                                      labelText: '${member['name']}',
                                      prefixIcon: Icon(Icons.person),
                                      suffixIcon: Text('\$', style: Theme.of(context).textTheme.bodyLarge),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _customSplitAmounts[memberId] = double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter an amount';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      if (double.parse(value) < 0) {
                                        return 'Amount cannot be negative';
                                      }
                                      return null;
                                    },
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 16),
                              Text(
                                'Total: \$${(double.tryParse(_amountController.text) ?? 0.0).toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                'Sum of individual shares: \$${_customSplitAmounts.values.fold(0.0, (sum, amount) => sum + amount).toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                'Remaining: \$${((double.tryParse(_amountController.text) ?? 0.0) - _customSplitAmounts.values.fold(0.0, (sum, amount) => sum + amount)).toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: ((double.tryParse(_amountController.text) ?? 0.0) - _customSplitAmounts.values.fold(0.0, (sum, amount) => sum + amount)).abs() > 0.01 ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
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