import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final List<String> groupIds;
  final List<String> invitationIds;
  final DateTime createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.groupIds,
    required this.invitationIds,
    required this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      groupIds: List<String>.from(data['groupIds'] ?? []),
      invitationIds: List<String>.from(data['invitationIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLogin: data['lastLogin'] != null 
          ? (data['lastLogin'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'groupIds': groupIds,
      'invitationIds': invitationIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
    };
  }

  UserModel copyWith({
    String? username,
    String? email,
    List<String>? groupIds,
    List<String>? invitationIds,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      groupIds: groupIds ?? this.groupIds,
      invitationIds: invitationIds ?? this.invitationIds,
      createdAt: this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
} 