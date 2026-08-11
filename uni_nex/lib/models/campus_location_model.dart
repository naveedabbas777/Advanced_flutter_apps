import 'package:flutter/material.dart';

class CampusLocation {
  final String id;
  final String name;
  final String description;
  final String category; // 'building', 'facility', 'parking', 'dining', etc.
  final String address;
  final double latitude;
  final double longitude;
  final bool isDefaultStartPoint;
  final String? imageUrl;
  final Map<String, dynamic> additionalInfo; // opening hours, contact info, etc.
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAddedByAdmin; // true if added by an admin

  CampusLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isDefaultStartPoint = false,
    this.imageUrl,
    this.additionalInfo = const {},
    this.createdAt,
    this.updatedAt,
    this.isAddedByAdmin = false,
  });

  // Convert from Firestore document
  factory CampusLocation.fromFirestore(Map<String, dynamic> data, String id) {
    return CampusLocation(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'building',
      address: data['address'] ?? '',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      isDefaultStartPoint: data['isDefaultStartPoint'] ?? false,
      imageUrl: data['imageUrl'],
      additionalInfo: data['additionalInfo'] ?? {},
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      isAddedByAdmin: data['isAddedByAdmin'] ?? false,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'isDefaultStartPoint': isDefaultStartPoint,
      'imageUrl': imageUrl,
      'additionalInfo': additionalInfo,
      'isAddedByAdmin': isAddedByAdmin,
      'createdAt': createdAt ?? DateTime.now(),
      'updatedAt': DateTime.now(),
    };
  }

  // Create copy with modifications
  CampusLocation copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? address,
    double? latitude,
    double? longitude,
    bool? isDefaultStartPoint,
    String? imageUrl,
    Map<String, dynamic>? additionalInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAddedByAdmin,
  }) {
    return CampusLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefaultStartPoint: isDefaultStartPoint ?? this.isDefaultStartPoint,
      imageUrl: imageUrl ?? this.imageUrl,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAddedByAdmin: isAddedByAdmin ?? this.isAddedByAdmin,
    );
  }

  // Get category icon
  IconData getCategoryIcon() {
    switch (category.toLowerCase()) {
      case 'building':
        return Icons.business;
      case 'facility':
        return Icons.room_service;
      case 'parking':
        return Icons.local_parking;
      case 'dining':
        return Icons.restaurant;
      case 'library':
        return Icons.library_books;
      case 'sports':
        return Icons.sports_soccer;
      case 'medical':
        return Icons.local_hospital;
      case 'transport':
        return Icons.directions_bus;
      default:
        return Icons.place;
    }
  }

  // Get category color
  Color getCategoryColor() {
    switch (category.toLowerCase()) {
      case 'building':
        return const Color(0xFF2196F3);
      case 'facility':
        return const Color(0xFF4CAF50);
      case 'parking':
        return const Color(0xFFFF9800);
      case 'dining':
        return const Color(0xFFE91E63);
      case 'library':
        return const Color(0xFF9C27B0);
      case 'sports':
        return const Color(0xFF00BCD4);
      case 'medical':
        return const Color(0xFFF44336);
      case 'transport':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF757575);
    }
  }
}

class CampusCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const CampusCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  static const List<CampusCategory> defaultCategories = [
    CampusCategory(
      id: 'building',
      name: 'Buildings',
      description: 'Academic and administrative buildings',
      icon: Icons.business,
      color: Color(0xFF2196F3),
    ),
    CampusCategory(
      id: 'facility',
      name: 'Facilities',
      description: 'Campus facilities and services',
      icon: Icons.room_service,
      color: Color(0xFF4CAF50),
    ),
    CampusCategory(
      id: 'parking',
      name: 'Parking',
      description: 'Parking areas and lots',
      icon: Icons.local_parking,
      color: Color(0xFFFF9800),
    ),
    CampusCategory(
      id: 'dining',
      name: 'Dining',
      description: 'Cafes, restaurants, and food services',
      icon: Icons.restaurant,
      color: Color(0xFFE91E63),
    ),
    CampusCategory(
      id: 'library',
      name: 'Library',
      description: 'Libraries and study areas',
      icon: Icons.library_books,
      color: Color(0xFF9C27B0),
    ),
    CampusCategory(
      id: 'sports',
      name: 'Sports',
      description: 'Sports facilities and fields',
      icon: Icons.sports_soccer,
      color: Color(0xFF00BCD4),
    ),
    CampusCategory(
      id: 'medical',
      name: 'Medical',
      description: 'Health and medical services',
      icon: Icons.local_hospital,
      color: Color(0xFFF44336),
    ),
    CampusCategory(
      id: 'transport',
      name: 'Transport',
      description: 'Transportation and shuttle services',
      icon: Icons.directions_bus,
      color: Color(0xFF795548),
    ),
  ];

  static CampusCategory? fromId(String id) {
    return defaultCategories.where((category) => category.id == id).firstOrNull;
  }
}
