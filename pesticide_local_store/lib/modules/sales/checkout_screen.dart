import 'package:flutter/material.dart';
import 'cart_model.dart';
import 'cart_firestore_service.dart';
import 'sale_confirmation_screen.dart';
import '../../modules/udhar/udhar_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutScreen extends StatefulWidget {
  final Cart cart;
  const CheckoutScreen({Key? key, required this.cart}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CartFirestoreService();
  final UdharFirestoreService _udharService = UdharFirestoreService();
  late SaleType _saleType;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _loading = false;
  List<Map<String, dynamic>> _udharCustomers = [];
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _saleType = widget.cart.saleType;
    _nameController = TextEditingController(text: widget.cart.customerName);
    _phoneController = TextEditingController(text: widget.cart.customerPhone);
    _fetchUdharCustomers();
  }

  Future<void> _fetchUdharCustomers() async {
    final snap = await _udharService.customers.get();
    setState(() {
      _udharCustomers =
          snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'phone': data['phone'] ?? '',
            };
          }).toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String?> _getOrAddUdharCustomer(String name, String phone) async {
    final found = _udharCustomers.firstWhere(
      (c) => c['name'] == name && c['phone'] == phone,
      orElse: () => {},
    );
    if (found.isNotEmpty) return found['id'];
    // Prompt for required fields if missing (for now, use empty string for fatherName and address)
    final doc = await _udharService.addCustomer(
      name: name,
      fatherName: '', // You may want to prompt the user for this
      phone1: phone,
      address: '', // You may want to prompt the user for this
    );
    await _fetchUdharCustomers();
    return doc.id;
  }

  Future<void> _confirmSale() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final cart = widget.cart;
      cart.saleType = _saleType;
      cart.customerName = _nameController.text;
      // Always use the phone associated with the selected customer if available
      if (_saleType == SaleType.udhar && _selectedCustomerId != null) {
        final selected = _udharCustomers.firstWhere(
          (c) => c['id'] == _selectedCustomerId,
          orElse: () => {},
        );
        if (selected.isNotEmpty) {
          cart.customerPhone = selected['phone'];
        } else {
          cart.customerPhone = _phoneController.text;
        }
      } else {
        cart.customerPhone = _phoneController.text;
      }

      String? udharCustomerId;
      if (_saleType == SaleType.udhar) {
        udharCustomerId = await _getOrAddUdharCustomer(
          _nameController.text.trim(),
          cart.customerPhone.trim(),
        );
      }

      final invoiceId = await _service.addSale(cart);

      if (_saleType == SaleType.udhar && udharCustomerId != null) {
        await _udharService.addCreditEntry(
          udharCustomerId,
          cart.totalPrice,
          'Sale Invoice: $invoiceId',
        );
      }

      setState(() => _loading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => SaleConfirmationScreen(cart: cart, invoiceId: invoiceId),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      String errorMessage = 'An error occurred while processing the sale.';

      if (e.toString().contains('Insufficient stock')) {
        errorMessage =
            'One or more products have insufficient stock. Please check your cart and try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (value.trim().length < 3) return 'Name too short';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim()))
      return 'Only letters and spaces allowed';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final exists = _udharCustomers.any(
      (c) =>
          c['phone'] == value.trim() &&
          c['name'] != _nameController.text.trim(),
    );
    if (exists) return 'Phone already used for another customer';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: const Text('Total'),
                        trailing: Text(
                          'Rs. ${widget.cart.totalPrice}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SaleType>(
                        value: _saleType,
                        items: const [
                          DropdownMenuItem(
                            value: SaleType.naqad,
                            child: Text('Naqad (Cash)'),
                          ),
                          DropdownMenuItem(
                            value: SaleType.udhar,
                            child: Text('Udhar (Credit)'),
                          ),
                        ],
                        onChanged: (val) => setState(() => _saleType = val!),
                        decoration: const InputDecoration(
                          labelText: 'Sale Type',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_saleType == SaleType.udhar)
                        Autocomplete<Map<String, dynamic>>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') {
                              return const Iterable<
                                Map<String, dynamic>
                              >.empty();
                            }
                            return _udharCustomers.where(
                              (c) =>
                                  c['name'].toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ) ||
                                  c['phone'].toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ),
                            );
                          },
                          displayStringForOption:
                              (c) => '${c['name']} (${c['phone']})',
                          fieldViewBuilder: (
                            context,
                            controller,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            controller.text = _nameController.text;
                            // Autofill phone only if name matches unique customer and phone field is empty
                            final matches =
                                _udharCustomers
                                    .where(
                                      (c) =>
                                          c['name'].toLowerCase() ==
                                          _nameController.text
                                              .trim()
                                              .toLowerCase(),
                                    )
                                    .toList();
                            if (matches.length == 1 &&
                                (_phoneController.text.isEmpty ||
                                    _phoneController.text !=
                                        matches.first['phone'])) {
                              _phoneController.text = matches.first['phone'];
                            }
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer Name',
                                  ),
                                  validator: _validateName,
                                  onChanged: (val) {
                                    final matches =
                                        _udharCustomers
                                            .where(
                                              (c) =>
                                                  c['name'].toLowerCase() ==
                                                  val.trim().toLowerCase(),
                                            )
                                            .toList();
                                    if (matches.length == 1 &&
                                        (_phoneController.text.isEmpty ||
                                            _phoneController.text !=
                                                matches.first['phone'])) {
                                      _phoneController.text =
                                          matches.first['phone'];
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer Phone',
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: _validatePhone,
                                ),
                              ],
                            );
                          },
                          onSelected: (c) {
                            _nameController.text = c['name'];
                            _phoneController.text = c['phone'];
                            _selectedCustomerId = c['id'];
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Material(
                              elevation: 4,
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children:
                                    options.map((c) {
                                      final isSelected =
                                          _nameController.text == c['name'] &&
                                          _phoneController.text == c['phone'];
                                      return ListTile(
                                        title: Text(
                                          '${c['name']} (${c['phone']})',
                                        ),
                                        tileColor:
                                            isSelected
                                                ? Colors.yellow[100]
                                                : null,
                                        onTap: () => onSelected(c),
                                      );
                                    }).toList(),
                              ),
                            );
                          },
                        ),
                      if (_saleType != SaleType.udhar) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                          ),
                          validator:
                              (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Phone',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmSale,
                          child: const Text('Confirm Sale'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
