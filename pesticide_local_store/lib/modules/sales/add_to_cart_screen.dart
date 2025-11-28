import 'package:flutter/material.dart';
import '../products/product_model.dart';
import '../products/product_firestore_service.dart';
import 'cart_model.dart';
import 'cart_summary_screen.dart';

// Place this after imports, before AddToCartScreen
class QuantitySelector extends StatelessWidget {
  final int value;
  final int maxStock;
  final ValueChanged<int> onChanged;
  const QuantitySelector({
    Key? key,
    required this.value,
    required this.maxStock,
    required this.onChanged,
  }) : super(key: key);

  void _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Quantity'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter quantity (max: $maxStock)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                int qty = int.tryParse(controller.text) ?? value;
                if (qty < 1) qty = 1;
                if (qty > maxStock) qty = maxStock;
                Navigator.pop(context, qty);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (result != null && result != value) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          color: value > 1 ? Colors.deepPurple : Colors.grey,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.deepPurple, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit quantity',
                onPressed: () => _showEditDialog(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < maxStock ? () => onChanged(value + 1) : null,
          color: value < maxStock ? Colors.deepPurple : Colors.grey,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Max: $maxStock',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class AddToCartScreen extends StatefulWidget {
  const AddToCartScreen({Key? key}) : super(key: key);

  @override
  State<AddToCartScreen> createState() => _AddToCartScreenState();
}

class _AddToCartScreenState extends State<AddToCartScreen> {
  final ProductFirestoreService _productService = ProductFirestoreService();
  final List<CartItem> _cartItems = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize quantities to 1 for all products
    // _initializeQuantities(); // Removed as per edit hint
  }

  // void _initializeQuantities() { // Removed as per edit hint
  //   _productService.getProducts().listen((products) {
  //     for (var product in products) {
  //       if (!_quantities.containsKey(product.id)) {
  //         _quantities[product.id] = 1;
  //       }
  //       if (!_quantityControllers.containsKey(product.id)) {
  //         _quantityControllers[product.id] = TextEditingController(text: '1');
  //       }
  //     }
  //   });
  // }

  void _addToCart(Product product) {
    final qty = 1; // Quantity is now managed in cart summary

    // Check if product is already in cart
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Update existing cart item
      _cartItems[existingIndex].quantity = qty;
    } else {
      // Add new cart item
      _cartItems.add(CartItem(product: product, quantity: qty));
    }

    setState(() {});
  }

  void _removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    setState(() {});
  }

  // void _updateQuantity(String productId, int newQuantity, {int? maxStock}) { // Removed as per edit hint
  //   final clampedQuantity =
  //       newQuantity < 1
  //           ? 1
  //           : (maxStock != null && newQuantity > maxStock
  //               ? maxStock
  //               : newQuantity);
  //   setState(() {
  //     _quantities[productId] = clampedQuantity;
  //     if (_quantityControllers.containsKey(productId)) {
  //       _quantityControllers[productId]!.text = clampedQuantity.toString();
  //       _quantityControllers[productId]!.selection = TextSelection.fromPosition(
  //         TextPosition(offset: _quantityControllers[productId]!.text.length),
  //       );
  //     }
  //   });
  // }

  void _goToSummary() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to cart'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CartSummaryScreen(cart: Cart(items: List.from(_cartItems))),
      ),
    );
  }

  Widget _buildStockIndicator(int stock) {
    Color color;
    String text;

    if (stock <= 0) {
      color = Colors.red;
      text = 'Out of Stock';
    } else if (stock <= 5) {
      color = Colors.orange;
      text = 'Low Stock: $stock';
    } else {
      color = Colors.green;
      text = 'In Stock: $stock';
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
        title: const Text('Add to Cart'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_cartItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_cartItems.length} items',
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.deepPurple,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.yellow[50],
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            // Products List
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: _productService.getProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: Text('No products available'));
                  }

                  final products = snapshot.data!;
                  final filtered =
                      products
                          .where(
                            (p) =>
                                _searchQuery.isEmpty ||
                                p.name.toLowerCase().contains(_searchQuery),
                          )
                          .toList();

                  final zeroStockIds =
                      products
                          .where((p) => p.quantity <= 0)
                          .map((p) => p.id)
                          .toList();
                  if (zeroStockIds.any(
                    (id) => _cartItems.any((item) => item.product.id == id),
                  )) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _cartItems.removeWhere(
                          (item) => zeroStockIds.contains(item.product.id),
                        );
                      });
                    });
                  }

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No products match your search.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      final currentQuantity =
                          1; // Quantity is now managed in cart summary
                      final isInCart = _cartItems.any(
                        (item) => item.product.id == product.id,
                      );
                      final isOutOfStock = product.quantity <= 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Colors.deepPurple.withOpacity(0.15),
                          ),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (product.unit.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 6.0,
                                                ),
                                                child: Text(
                                                  'Unit: ${product.unit}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.deepPurple,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          'Company: ${product.company}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Category: ${product.category}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Price: Rs. ${product.salePrice.toStringAsFixed(2)} per ${product.unit}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.deepPurple,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStockIndicator(product.quantity),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!isOutOfStock) ...[
                                // QuantitySelector removed; only show Add to Cart button
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            isInCart || isOutOfStock
                                                ? null
                                                : () => _addToCart(product),
                                        icon: Icon(
                                          isInCart
                                              ? Icons.check
                                              : Icons.shopping_cart,
                                        ),
                                        label: Text(
                                          isInCart
                                              ? 'Added to Cart'
                                              : 'Add to Cart',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              isInCart
                                                  ? Colors.green
                                                  : Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isInCart) ...[
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed:
                                            () => _removeFromCart(product.id),
                                        icon: const Icon(
                                          Icons.remove_shopping_cart,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Remove from Cart',
                                      ),
                                    ],
                                  ],
                                ),
                              ] else ...[
                                const Center(
                                  child: Text(
                                    'Out of Stock',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToSummary,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shopping_cart_checkout),
        label: Text('Checkout (${_cartItems.length})'),
        tooltip: 'Go to Cart Summary',
      ),
    );
  }
}
