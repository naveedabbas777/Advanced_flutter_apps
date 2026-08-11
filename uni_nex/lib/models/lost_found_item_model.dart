import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Status lifecycle: pending → approved/rejected → claimed
enum LostFoundStatus { pending, approved, rejected, claimed }

extension LostFoundStatusExtension on LostFoundStatus {
  String get displayName {
    switch (this) {
      case LostFoundStatus.pending:
        return 'Pending Review';
      case LostFoundStatus.approved:
        return 'Approved';
      case LostFoundStatus.rejected:
        return 'Rejected';
      case LostFoundStatus.claimed:
        return 'Claimed';
    }
  }

  Color get color {
    switch (this) {
      case LostFoundStatus.pending:
        return const Color(0xFFFF9800); // Orange
      case LostFoundStatus.approved:
        return const Color(0xFF4CAF50); // Green
      case LostFoundStatus.rejected:
        return const Color(0xFFF44336); // Red
      case LostFoundStatus.claimed:
        return const Color(0xFF2196F3); // Blue
    }
  }

  IconData get icon {
    switch (this) {
      case LostFoundStatus.pending:
        return Icons.hourglass_empty;
      case LostFoundStatus.approved:
        return Icons.check_circle;
      case LostFoundStatus.rejected:
        return Icons.cancel;
      case LostFoundStatus.claimed:
        return Icons.verified;
    }
  }
}

/// Categories for found items
class LostFoundCategory {
  static const String electronics = 'electronics';
  static const String accessories = 'accessories';
  static const String clothing = 'clothing';
  static const String books = 'books';
  static const String idCard = 'id_card';
  static const String keys = 'keys';
  static const String wallet = 'wallet';
  static const String other = 'other';

  static const List<String> all = [
    electronics,
    accessories,
    clothing,
    books,
    idCard,
    keys,
    wallet,
    other,
  ];

  static String displayName(String category) {
    switch (category) {
      case electronics:
        return 'Electronics';
      case accessories:
        return 'Accessories';
      case clothing:
        return 'Clothing';
      case books:
        return 'Books';
      case idCard:
        return 'ID Card';
      case keys:
        return 'Keys';
      case wallet:
        return 'Wallet';
      case other:
        return 'Other';
      default:
        return category;
    }
  }

  static IconData icon(String category) {
    switch (category) {
      case electronics:
        return Icons.devices;
      case accessories:
        return Icons.watch;
      case clothing:
        return Icons.checkroom;
      case books:
        return Icons.menu_book;
      case idCard:
        return Icons.badge;
      case keys:
        return Icons.key;
      case wallet:
        return Icons.account_balance_wallet;
      case other:
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  static Color color(String category) {
    switch (category) {
      case electronics:
        return const Color(0xFF2196F3);
      case accessories:
        return const Color(0xFFE91E63);
      case clothing:
        return const Color(0xFF9C27B0);
      case books:
        return const Color(0xFF4CAF50);
      case idCard:
        return const Color(0xFFFF5722);
      case keys:
        return const Color(0xFF795548);
      case wallet:
        return const Color(0xFF607D8B);
      case other:
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

class LostFoundItem {
  final String id;
  final String itemName;
  final String description;
  final String category;
  final String foundLocation;
  final DateTime foundDate;
  final String finderUserId;
  final String finderName;
  final String? finderContact;
  final String? imageUrl;
  final LostFoundStatus status;
  final String? adminNote;
  final DateTime? approvedAt;
  final DateTime? claimedAt;
  final String? claimedByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LostFoundItem({
    required this.id,
    required this.itemName,
    required this.description,
    required this.category,
    required this.foundLocation,
    required this.foundDate,
    required this.finderUserId,
    required this.finderName,
    this.finderContact,
    this.imageUrl,
    this.status = LostFoundStatus.pending,
    this.adminNote,
    this.approvedAt,
    this.claimedAt,
    this.claimedByUserId,
    this.createdAt,
    this.updatedAt,
  });

  // Convert from Firestore document
  factory LostFoundItem.fromFirestore(Map<String, dynamic> data, String id) {
    return LostFoundItem(
      id: id,
      itemName: data['itemName'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? LostFoundCategory.other,
      foundLocation: data['foundLocation'] ?? '',
      foundDate: _parseDate(data['foundDate']),
      finderUserId: data['finderUserId'] ?? '',
      finderName: data['finderName'] ?? '',
      finderContact: data['finderContact'],
      imageUrl: data['imageUrl'],
      status: _parseStatus(data['status']),
      adminNote: data['adminNote'],
      approvedAt: _parseDateNullable(data['approvedAt']),
      claimedAt: _parseDateNullable(data['claimedAt']),
      claimedByUserId: data['claimedByUserId'],
      createdAt: _parseDateNullable(data['createdAt']),
      updatedAt: _parseDateNullable(data['updatedAt']),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'itemName': itemName,
      'description': description,
      'category': category,
      'foundLocation': foundLocation,
      'foundDate': Timestamp.fromDate(foundDate),
      'finderUserId': finderUserId,
      'finderName': finderName,
      'finderContact': finderContact,
      'imageUrl': imageUrl,
      'status': status.name,
      'adminNote': adminNote,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'claimedByUserId': claimedByUserId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create copy with modifications
  LostFoundItem copyWith({
    String? id,
    String? itemName,
    String? description,
    String? category,
    String? foundLocation,
    DateTime? foundDate,
    String? finderUserId,
    String? finderName,
    String? finderContact,
    String? imageUrl,
    LostFoundStatus? status,
    String? adminNote,
    DateTime? approvedAt,
    DateTime? claimedAt,
    String? claimedByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LostFoundItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      category: category ?? this.category,
      foundLocation: foundLocation ?? this.foundLocation,
      foundDate: foundDate ?? this.foundDate,
      finderUserId: finderUserId ?? this.finderUserId,
      finderName: finderName ?? this.finderName,
      finderContact: finderContact ?? this.finderContact,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
      approvedAt: approvedAt ?? this.approvedAt,
      claimedAt: claimedAt ?? this.claimedAt,
      claimedByUserId: claimedByUserId ?? this.claimedByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper to get how long ago the item was found
  String get foundAgo {
    final now = DateTime.now();
    final diff = now.difference(foundDate);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }

  // Helpers
  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static LostFoundStatus _parseStatus(dynamic value) {
    if (value is String) {
      switch (value) {
        case 'pending':
          return LostFoundStatus.pending;
        case 'approved':
          return LostFoundStatus.approved;
        case 'rejected':
          return LostFoundStatus.rejected;
        case 'claimed':
          return LostFoundStatus.claimed;
      }
    }
    return LostFoundStatus.pending;
  }
}
