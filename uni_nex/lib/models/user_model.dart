import 'package:flutter/material.dart';

enum UserRole { user, admin }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.user:
        return 'User';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  String get description {
    switch (this) {
      case UserRole.user:
        return 'Access to campus services and events';
      case UserRole.admin:
        return 'Full administrative access and management tools';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.user:
        return Icons.person;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.user:
        return const Color(0xFF2196F3);
      case UserRole.admin:
        return const Color(0xFFE91E63);
    }
  }

  int get priority {
    switch (this) {
      case UserRole.user:
        return 1;
      case UserRole.admin:
        return 2;
    }
  }
}

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String? profileImageUrl;
  final UserRole role;
  final String? studentId;
  final String? department;
  final String? phoneNumber;
  final bool emailVerified;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> preferences;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.profileImageUrl,
    UserRole? role,
    this.studentId,
    this.department,
    this.phoneNumber,
    this.emailVerified = false,
    this.isActive = true,
    this.createdAt,
    this.lastLoginAt,
    this.updatedAt,
    this.preferences = const {},
  }) : role = role ?? UserRole.user;

  // Convert from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    final roleString = data['role'] as String?;
    final mappedRole = _mapRoleFromString(roleString);

    debugPrint(
      'UserModel.fromFirestore: uid=$uid, email=${data['email']}, roleString=$roleString, mappedRole=$mappedRole',
    );

    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      role: mappedRole,
      studentId: data['studentId'],
      department: data['department'],
      phoneNumber: data['phoneNumber'],
      emailVerified: data['emailVerified'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt']?.toDate(),
      lastLoginAt: data['lastLoginAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      preferences: data['preferences'] ?? {},
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'profileImageUrl': profileImageUrl,
      'role': role.name,
      'studentId': studentId,
      'department': department,
      'phoneNumber': phoneNumber,
      'emailVerified': emailVerified,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now(),
      'lastLoginAt': lastLoginAt ?? DateTime.now(),
      'updatedAt': DateTime.now(),
      'preferences': preferences,
    };
  }

  // Create copy with modifications
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? profileImageUrl,
    UserRole? role,
    String? studentId,
    String? department,
    String? phoneNumber,
    bool? emailVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      department: department ?? this.department,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailVerified: emailVerified ?? this.emailVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
    );
  }

  // Get display name
  String get displayName => fullName.isNotEmpty ? fullName : email;

  // Get initials for avatar
  String get initials {
    final nameParts = fullName.trim().split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  // Check permissions
  bool canManageEvents() => role == UserRole.admin;
  bool canManageUsers() => role == UserRole.admin;
  bool canManageLocations() => role == UserRole.admin;
  bool isAdmin() => role == UserRole.admin;

  // Helper method to map old roles to new roles
  static UserRole _mapRoleFromString(String? roleString) {
    if (roleString == null || roleString.isEmpty) return UserRole.user;

    final normalizedRole = roleString
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    switch (normalizedRole) {
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'student':
      case 'faculty':
      case 'staff':
      case 'user':
      default:
        return UserRole.user;
    }
  }

  // Get role-based greeting
  String getGreeting() {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    switch (role) {
      case UserRole.admin:
        return '$timeGreeting, Administrator ${fullName.split(' ').first}';
      case UserRole.user:
      default:
        return '$timeGreeting, ${fullName.split(' ').first}';
    }
  }
}

class UserPreferences {
  final bool notificationsEnabled;
  final bool darkMode;
  final String language;
  final List<String> favoriteLocations;
  final List<String> subscribedCategories;

  const UserPreferences({
    this.notificationsEnabled = true,
    this.darkMode = false,
    this.language = 'en',
    this.favoriteLocations = const [],
    this.subscribedCategories = const [],
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      darkMode: map['darkMode'] ?? false,
      language: map['language'] ?? 'en',
      favoriteLocations: List<String>.from(map['favoriteLocations'] ?? []),
      subscribedCategories: List<String>.from(
        map['subscribedCategories'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'darkMode': darkMode,
      'language': language,
      'favoriteLocations': favoriteLocations,
      'subscribedCategories': subscribedCategories,
    };
  }
}
