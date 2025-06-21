import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/expense_service.dart';
import '../../services/group_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;

  AddExpenseScreen({required this.groupId});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedPaidBy;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;
  final ExpenseService _expenseService = ExpenseService();
  final GroupService _groupService = GroupService();
  File? _selectedImage;
  String? _uploadedImageUrl;
  final List<String> _categories = ['Food', 'Travel', 'Utilities', 'Shopping', 'Other'];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      DocumentSnapshot groupDoc = await _groupService.getGroupDetails(widget.groupId);
      List<dynamic> memberIds = groupDoc['members'] ?? [];

      List<Map<String, dynamic>> loadedMembers = [];
      for (String memberId in memberIds) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists) {
          loadedMembers.add({
            'id': memberId,
            'username': userDoc['username'] ?? 'Unknown User',
          });
        }
      }
      
      setState(() {
        _members = loadedMembers;
        if (_members.isNotEmpty) {
          _selectedPaidBy = _members[0]['id'];
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (_formKey.currentState!.validate() && _selectedPaidBy != null) {
      setState(() => _isLoading = true);
      try {
        String? imageUrl;
        if (_selectedImage != null) {
          imageUrl = await _uploadImage(_selectedImage!);
          if (imageUrl == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload expense attachment.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
            return;
          }
        }
        await _expenseService.addExpense(
          groupId: widget.groupId,
          title: _titleController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
          paidBy: _selectedPaidBy!,
          notes: _notesController.text.trim(),
          imageUrl: imageUrl,
          category: _selectedCategory,
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileName = 'expense_attachments/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
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
              if (_members.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Paid By',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedPaidBy,
                  items: _members.map((member) {
                    return DropdownMenuItem<String>(
                      value: member['id'] as String,
                      child: Text(member['username'] as String),
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
                )
              else
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Loading members...'),
                  ),
                ),
              SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file),
                    tooltip: 'Attach Receipt',
                    onPressed: _isLoading ? null : _pickImage,
                  ),
                  if (_selectedImage != null)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: InteractiveViewer(
                              child: Image.file(_selectedImage!),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (val) => val == null ? 'Please select a category' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _addExpense,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Add Expense'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 