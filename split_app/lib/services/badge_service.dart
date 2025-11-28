import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

// flutter_app_badger is discontinued and causing build issues
// App icon badges are disabled for now
// TODO: Find alternative package or implement native solution

class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _badgeSubscription;
  String? _currentUserId;

  Future<void> startTracking(String userId) async {
    if (_currentUserId == userId && _badgeSubscription != null) {
      return; // Already tracking
    }

    await stopTracking();
    _currentUserId = userId;

    // Listen to all badge-related collections and update app icon badge
    _badgeSubscription =
        Stream.periodic(const Duration(seconds: 5)).listen((_) {
      _updateAppIconBadge(userId);
    });

    // Initial update
    await _updateAppIconBadge(userId);
  }

  Future<void> stopTracking() async {
    await _badgeSubscription?.cancel();
    _badgeSubscription = null;
    _currentUserId = null;
    // App icon badge functionality disabled (flutter_app_badger is discontinued)
  }

  Future<void> _updateAppIconBadge(String userId) async {
    try {
      int totalBadgeCount = 0;

      // Count pending invitations
      final invitationsSnapshot = await _firestore
          .collection('group_invitations')
          .where('invitedUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      totalBadgeCount += invitationsSnapshot.docs.length;

      // Count unread group messages
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('memberIds', arrayContains: userId)
          .get();

      for (var groupDoc in groupsSnapshot.docs) {
        final groupId = groupDoc.id;

        // Get last seen for messages
        final chatViewDoc = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('chatViews')
            .doc(userId)
            .get();

        Timestamp? lastSeenMsg;
        if (chatViewDoc.exists) {
          lastSeenMsg = chatViewDoc.data()?['lastSeen'] as Timestamp?;
        }

        final messagesQuery = await _firestore
            .collection('group_messages')
            .where('groupId', isEqualTo: groupId)
            .get();

        if (lastSeenMsg != null) {
          final unreadMessages = messagesQuery.docs.where((doc) {
            final ts = doc.data()['timestamp'] as Timestamp?;
            final senderId = doc.data()['senderId'] as String?;
            return ts != null &&
                ts.toDate().isAfter(lastSeenMsg!.toDate()) &&
                senderId != userId;
          }).length;
          totalBadgeCount += unreadMessages;
        } else {
          final unreadMessages = messagesQuery.docs
              .where((doc) => doc.data()['senderId'] != userId)
              .length;
          totalBadgeCount += unreadMessages;
        }
      }

      // Count unread direct messages
      final directChatsSnapshot = await _firestore
          .collection('direct_chats')
          .where('participants', arrayContains: userId)
          .get();

      for (var chatDoc in directChatsSnapshot.docs) {
        final chatId = chatDoc.id;

        // Get last seen for direct chat
        final chatViewDoc = await _firestore
            .collection('direct_chats')
            .doc(chatId)
            .collection('chatViews')
            .doc(userId)
            .get();

        Timestamp? lastSeen;
        if (chatViewDoc.exists) {
          lastSeen = chatViewDoc.data()?['lastSeen'] as Timestamp?;
        }

        final messagesQuery = await _firestore
            .collection('direct_messages')
            .where('chatId', isEqualTo: chatId)
            .get();

        if (lastSeen != null) {
          final unreadMessages = messagesQuery.docs.where((doc) {
            final ts = doc.data()['timestamp'] as Timestamp?;
            final senderId = doc.data()['senderId'] as String?;
            return ts != null &&
                ts.toDate().isAfter(lastSeen!.toDate()) &&
                senderId != userId;
          }).length;
          totalBadgeCount += unreadMessages;
        } else {
          final unreadMessages = messagesQuery.docs
              .where((doc) => doc.data()['senderId'] != userId)
              .length;
          totalBadgeCount += unreadMessages;
        }
      }

      // App icon badge functionality disabled (flutter_app_badger is discontinued)
      // Badge counts are still tracked and shown in-app via UI badges
      // TODO: Implement alternative solution for app icon badges
    } catch (e) {
      print('Error updating app icon badge: $e');
    }
  }

  Future<void> updateBadge() async {
    if (_currentUserId != null) {
      await _updateAppIconBadge(_currentUserId!);
    }
  }
}
