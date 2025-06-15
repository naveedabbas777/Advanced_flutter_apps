import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMember {
  final String userId;
  final String username;
  final String email;
  final bool isAdmin;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.username,
    required this.email,
    required this.isAdmin,
    required this.joinedAt,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    try {
      return GroupMember(
        userId: map['userId']?.toString() ?? '',
        username: map['username']?.toString() ?? 'Unknown User',
        email: map['email']?.toString() ?? '',
        isAdmin: map['isAdmin'] as bool? ?? false,
        joinedAt: map['joinedAt'] != null 
            ? (map['joinedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing group member: $e');
      return GroupMember(
        userId: '',
        username: 'Unknown User',
        email: '',
        isAdmin: false,
        joinedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'isAdmin': isAdmin,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}

class GroupModel {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final List<GroupMember> members;

  GroupModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.members,
  });

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<GroupMember> membersList = [];
    
    if (data['members'] != null) {
      try {
        membersList = (data['members'] as List)
            .map((member) => GroupMember.fromMap(member as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error parsing members: $e');
        membersList = [];
      }
    }

    return GroupModel(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Group',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      members: membersList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members.map((member) => member.toMap()).toList(),
    };
  }

  GroupModel copyWith({
    String? name,
    List<GroupMember>? members,
  }) {
    return GroupModel(
      id: this.id,
      name: name ?? this.name,
      createdBy: this.createdBy,
      createdAt: this.createdAt,
      members: members ?? this.members,
    );
  }
} 