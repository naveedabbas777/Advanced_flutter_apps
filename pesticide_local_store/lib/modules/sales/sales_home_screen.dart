import 'package:flutter/material.dart';
import 'add_to_cart_screen.dart';
import 'cart_model.dart';
import 'cart_summary_screen.dart';
import 'checkout_screen.dart';

class SalesHomeScreen extends StatefulWidget {
  const SalesHomeScreen({Key? key}) : super(key: key);

  @override
  State<SalesHomeScreen> createState() => _SalesHomeScreenState();
}

class _SalesHomeScreenState extends State<SalesHomeScreen> {
  Cart cart = Cart(items: []);

  void _goToAddToCart() async {
    final result = await Navigator.push<Cart>(
      context,
      MaterialPageRoute(builder: (_) => const AddToCartScreen()),
    );
    if (result != null) {
      setState(() => cart = result);
    }
  }

  void _goToCartSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartSummaryScreen(cart: cart)),
    );
  }

  void _goToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalItems = cart.items.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
    final double totalPrice = cart.items.fold(
      0,
      (sum, item) => sum + item.product.salePrice * item.quantity,
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sales'),
        backgroundColor: Colors.deepPurple.withOpacity(0.85),
        foregroundColor: Colors.white,
        elevation: 2,
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
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cart Summary Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart,
                            color: Colors.deepPurple,
                            size: 36,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cart Items: $totalItems',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                Text(
                                  'Total: Rs. ${totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.deepPurple,
                            ),
                            tooltip: 'Refresh',
                            onPressed: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Action Tiles
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.add_shopping_cart,
                        color: Colors.deepPurple,
                        size: 32,
                      ),
                      title: const Text(
                        'Add to Cart',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Browse and add products to your cart.',
                      ),
                      onTap: _goToAddToCart,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.list_alt,
                        color: Colors.deepPurple,
                        size: 32,
                      ),
                      title: const Text(
                        'View Cart Summary',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'See all items in your cart and adjust quantities.',
                      ),
                      onTap: _goToCartSummary,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.payment,
                        color: Colors.deepPurple,
                        size: 32,
                      ),
                      title: const Text(
                        'Checkout',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Proceed to payment and complete the sale.',
                      ),
                      onTap: _goToCheckout,
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Welcome/Info
                  Center(
                    child: Text(
                      'Welcome to Sales! Manage your cart and checkout with ease.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.deepPurple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
