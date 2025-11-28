import 'package:flutter/material.dart';
import 'cart_model.dart';
import 'checkout_screen.dart';
import '../products/product_firestore_service.dart';

class CartSummaryScreen extends StatefulWidget {
  final Cart cart;
  const CartSummaryScreen({Key? key, required this.cart}) : super(key: key);

  @override
  State<CartSummaryScreen> createState() => _CartSummaryScreenState();
}

class _CartSummaryScreenState extends State<CartSummaryScreen> {
  late List<CartItem> _items;
  final ProductFirestoreService _productService = ProductFirestoreService();
  final Map<String, int> _currentStock = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, FocusNode> _quantityFocusNodes = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.cart.items);
    for (var item in _items) {
      _quantityControllers[item.product.id] = TextEditingController(
        text: item.quantity.toString(),
      );
      _quantityFocusNodes[item.product.id] = FocusNode();
      _quantityFocusNodes[item.product.id]!.addListener(() {
        if (!_quantityFocusNodes[item.product.id]!.hasFocus &&
            (_quantityControllers[item.product.id]?.text.isEmpty ?? true)) {
          _quantityControllers[item.product.id]?.text = '1';
          _updateQuantity(_items.indexOf(item), 1);
        }
      });
    }
    _loadCurrentStock();
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var node in _quantityFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCurrentStock() async {
    setState(() => _loading = true);
    for (var item in _items) {
      final stock = await _productService.getCurrentStock(item.product.id);
      _currentStock[item.product.id] = stock;
    }
    setState(() => _loading = false);
  }

  void _updateQuantity(int index, int newQty) {
    final item = _items[index];
    final currentStock = _currentStock[item.product.id] ?? 0;

    if (newQty > 0 && newQty <= currentStock) {
      setState(() {
        _items[index].quantity = newQty;
      });
    } else if (newQty > currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $currentStock items available in stock'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _totalPrice => _items.fold(
    0,
    (sum, item) => sum + item.product.salePrice * item.quantity,
  );

  void _proceedToCheckout() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to cart'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final updatedCart = Cart(items: _items);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(cart: updatedCart)),
    );
  }

  Widget _buildStockIndicator(int currentStock, int requestedQty) {
    Color color;
    String text;

    if (currentStock <= 0) {
      color = Colors.red;
      text = 'Out of Stock';
    } else if (currentStock < requestedQty) {
      color = Colors.orange;
      text = 'Low Stock: $currentStock (Need: $requestedQty)';
    } else {
      color = Colors.green;
      text = 'Available: $currentStock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart Summary'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentStock,
            tooltip: 'Refresh Stock',
          ),
        ],
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
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Your cart is empty.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final currentStock = _currentStock[item.product.id] ?? 0;
                      final remainingStock = currentStock - item.quantity;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.deepPurple,
                                    child: Text(
                                      item.product.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Company: ${item.product.company}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStockIndicator(
                                    currentStock,
                                    item.quantity,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    'Price: Rs. ${item.product.salePrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Total: Rs. ${(item.product.salePrice * item.quantity).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: TextField(
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      controller:
                                          _quantityControllers[item.product.id],
                                      onTap: () {
                                        _quantityControllers[item.product.id]
                                            ?.clear();
                                      },
                                      onChanged: (value) {
                                        if (value.isEmpty) {
                                          _updateQuantity(index, 1);
                                          return;
                                        }
                                        final qty = int.tryParse(value);
                                        if (qty == null || qty < 1) {
                                          _updateQuantity(index, 1);
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                _quantityControllers[item
                                                        .product
                                                        .id]
                                                    ?.text = '1';
                                                _quantityControllers[item
                                                            .product
                                                            .id]
                                                        ?.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset:
                                                            _quantityControllers[item
                                                                    .product
                                                                    .id]
                                                                ?.text
                                                                .length ??
                                                            0,
                                                      ),
                                                    );
                                              });
                                        } else if (qty > currentStock) {
                                          _updateQuantity(index, currentStock);
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                _quantityControllers[item
                                                            .product
                                                            .id]
                                                        ?.text =
                                                    currentStock.toString();
                                                _quantityControllers[item
                                                            .product
                                                            .id]
                                                        ?.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset:
                                                            _quantityControllers[item
                                                                    .product
                                                                    .id]
                                                                ?.text
                                                                .length ??
                                                            0,
                                                      ),
                                                    );
                                              });
                                        } else {
                                          _updateQuantity(index, qty);
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      focusNode:
                                          _quantityFocusNodes[item.product.id],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Max: $currentStock',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (remainingStock >= 0)
                                          Text(
                                            'Remaining: $remainingStock',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  remainingStock <= 5
                                                      ? Colors.orange
                                                      : Colors.green,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeItem(index),
                                    tooltip: 'Remove',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Rs. ${_totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80), // Add space for the button
                  ],
                ),
      ),
      bottomNavigationBar:
          _items.isEmpty
              ? null
              : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.deepPurple,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _items.isEmpty ? null : _proceedToCheckout,
                    child: const Text('Proceed to Checkout'),
                  ),
                ),
              ),
    );
  }
}
