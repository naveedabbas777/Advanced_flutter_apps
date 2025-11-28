import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String company;
  final String category;
  final String group;
  final String code;
  final double purchasePrice;
  final double salePrice;
  final int quantity;
  final DateTime expiryDate;
  final String unit;

  Product({
    required this.id,
    required this.name,
    required this.company,
    required this.category,
    required this.group,
    required this.code,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    required this.expiryDate,
    required this.unit,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      company: map['company'] ?? '',
      category: map['category'] ?? '',
      group: map['group'] ?? '',
      code: map['code'] ?? '',
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      salePrice: (map['salePrice'] ?? 0).toDouble(),
      quantity: (map['quantity'] ?? 0).toInt(),
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      unit: map['unit'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'company': company,
      'category': category,
      'group': group,
      'code': code,
      'purchasePrice': purchasePrice,
      'salePrice': salePrice,
      'quantity': quantity,
      'expiryDate': expiryDate,
      'unit': unit,
    };
  }
}
