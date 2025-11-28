import '../products/product_model.dart';

enum SaleType { naqad, udhar }

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, required this.quantity});
}

class Cart {
  final List<CartItem> items;
  SaleType saleType;
  String customerName;
  String customerPhone;

  Cart({
    required this.items,
    this.saleType = SaleType.naqad,
    this.customerName = '',
    this.customerPhone = '',
  });

  double get totalPrice => items.fold(
    0,
    (sum, item) => sum + item.product.salePrice * item.quantity,
  );
}
