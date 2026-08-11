import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final String? locationTag;
  final double? latitude;
  final double? longitude;
  final String category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    this.locationTag,
    this.latitude,
    this.longitude,
    required this.category,
    this.createdAt,
    this.updatedAt,
  });

  // Convert from Firestore document
  factory EventModel.fromFirestore(Map<String, dynamic> data, String id) {
    final rawDate = data['date'];
    final rawLatitude = data['latitude'];
    final rawLongitude = data['longitude'];

    return EventModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: rawDate is Timestamp
          ? rawDate.toDate()
          : rawDate is DateTime
          ? rawDate
          : DateTime.now(),
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      locationTag: data['locationTag'] as String?,
      latitude: rawLatitude is num ? rawLatitude.toDouble() : null,
      longitude: rawLongitude is num ? rawLongitude.toDouble() : null,
      category: data['category'] ?? 'general',
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'location': location,
      'locationTag': locationTag,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'createdAt': createdAt ?? DateTime.now(),
      'updatedAt': DateTime.now(),
    };
  }

  // Create copy with modifications
  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? location,
    String? locationTag,
    double? latitude,
    double? longitude,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      locationTag: locationTag ?? this.locationTag,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class QuickActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class NavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
