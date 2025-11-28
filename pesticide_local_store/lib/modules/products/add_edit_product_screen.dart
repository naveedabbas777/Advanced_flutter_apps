import 'package:flutter/material.dart';
import 'product_model.dart';
import 'product_firestore_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  const AddEditProductScreen({Key? key, this.product}) : super(key: key);

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductFirestoreService();

  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _categoryController;
  late TextEditingController _groupController;
  late TextEditingController _codeController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _salePriceController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _companyController = TextEditingController(text: p?.company ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _groupController = TextEditingController(text: p?.group ?? '');
    _codeController = TextEditingController(text: p?.code ?? '');
    _purchasePriceController = TextEditingController(
      text: p?.purchasePrice.toString() ?? '',
    );
    _salePriceController = TextEditingController(
      text: p?.salePrice.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: p?.quantity.toString() ?? '',
    );
    _unitController = TextEditingController(text: p?.unit ?? '');
    _expiryDate = p?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _categoryController.dispose();
    _groupController.dispose();
    _codeController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _save() async {
    if (!_formKey.currentState!.validate() || _expiryDate == null) return;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
    final salePrice = double.tryParse(_salePriceController.text) ?? 0;
    if (widget.product == null && salePrice < purchasePrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale price cannot be less than purchase price.'),
        ),
      );
      return;
    }
    final product = Product(
      id: widget.product?.id ?? '',
      name: _nameController.text,
      company: _companyController.text,
      category: _categoryController.text,
      group: _groupController.text,
      code: _codeController.text,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      quantity: int.tryParse(_quantityController.text) ?? 0,
      expiryDate: _expiryDate!,
      unit: _unitController.text,
    );
    if (widget.product == null) {
      await _service.addProduct(product);
    } else {
      await _service.updateProduct(product);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _groupController,
                  decoration: const InputDecoration(labelText: 'Group'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purchasePriceController,
                  decoration: const InputDecoration(
                    labelText: 'Purchase Price',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _salePriceController,
                  decoration: const InputDecoration(labelText: 'Sale Price'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _expiryDate == null
                            ? 'No Expiry Date Chosen'
                            : 'Expiry: ${_expiryDate!.toLocal().toString().split(' ')[0]}',
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDate,
                      child: const Text('Pick Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(
                      widget.product == null ? 'Add Product' : 'Save Changes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
