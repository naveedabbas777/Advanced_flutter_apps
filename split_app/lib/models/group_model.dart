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
    return GroupMember(
      userId: map['userId'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      isAdmin: map['isAdmin'] as bool,
      joinedAt: map['joinedAt'] is String
          ? DateTime.parse(map['joinedAt'])
          : (map['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'isAdmin': isAdmin,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}

class GroupModel {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final List<GroupMember> members;
  final List<String> memberIds;
  final String? photoUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  GroupModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.memberIds,
    this.photoUrl,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Group',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      members: (data['members'] as List<dynamic>?)
              ?.map((memberData) => GroupMember.fromMap(memberData as Map<String, dynamic>))
              .toList() ??
          [],
      memberIds: List<String>.from(data['memberIds'] ?? []),
      photoUrl: data['photoUrl'],
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'members': members.map((member) => member.toMap()).toList(),
      'memberIds': memberIds,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? createdBy,
    DateTime? createdAt,
    List<GroupMember>? members,
    List<String>? memberIds,
    String? photoUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      memberIds: memberIds ?? this.memberIds,
      photoUrl: photoUrl ?? this.photoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'members': members.map((m) => m.toMap()).toList(),
      'memberIds': memberIds,
      'photoUrl': photoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
    };
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
      members: (json['members'] as List)
          .map((m) => GroupMember.fromMap(m))
          .toList(),
      memberIds: List<String>.from(json['memberIds'] ?? []),
      photoUrl: json['photoUrl'],
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : null,
    );
  }
} 