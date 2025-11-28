import 'package:flutter/material.dart';
import '../products/product_firestore_service.dart';
import '../products/product_model.dart';
import 'dart:async';

class StockDataScreen extends StatefulWidget {
  const StockDataScreen({Key? key}) : super(key: key);

  @override
  State<StockDataScreen> createState() => _StockDataScreenState();
}

class _StockDataScreenState extends State<StockDataScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Removed timer initialization
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) return products;
    return products
        .where(
          (product) =>
              product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.company.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              product.category.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final service = ProductFirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Real-Time Stock Data')),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search products by name, company, or category...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.deepPurple,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.deepPurple,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.deepPurple),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Product>>(
                  stream: service.getProducts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final products = snapshot.data ?? [];
                    final filteredProducts = _filterProducts(products);
                    if (filteredProducts.isEmpty) {
                      return const Center(child: Text('No products found.'));
                    }
                    return ListView(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            'All Products (Real-Time):',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...filteredProducts.map(
                          (product) => Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.inventory,
                                color: Colors.deepPurple,
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Company: ${product.company}'),
                                  Text('Category: ${product.category}'),
                                  Text(
                                    'Stock: ${product.quantity} ${product.unit}',
                                  ),
                                  Text(
                                    'Expiry: ${product.expiryDate != null ? product.expiryDate.toLocal().toString().split(' ')[0] : 'N/A'}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
