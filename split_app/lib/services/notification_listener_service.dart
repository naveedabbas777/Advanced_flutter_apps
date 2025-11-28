import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'notification_service.dart';

class NotificationListenerService {
  static final NotificationListenerService _instance =
      NotificationListenerService._internal();
  factory NotificationListenerService() => _instance;
  NotificationListenerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  List<StreamSubscription> _subscriptions = [];
  String? _currentUserId;
  List<String> _userGroupIds = [];
  DateTime? _listeningStartTime; // Track when we started listening

  // Track processed notifications to prevent duplicates
  final Map<String, DateTime> _processedInvitations = {};
  final Map<String, DateTime> _processedExpenses = {};
  final Map<String, DateTime> _processedMessages = {};
  final Map<String, DateTime> _processedSettlements = {};

  Future<void> startListening(String userId) async {
    if (_currentUserId == userId && _subscriptions.isNotEmpty) {
      return; // Already listening
    }

    await stopListening(); // Clean up any existing listeners
    _currentUserId = userId;
    _listeningStartTime = DateTime.now(); // Record when we start listening

    // Get user's groups
    await _loadUserGroups(userId);

    // Listen for group invitations
    _subscriptions.add(
      _firestore
          .collection('group_invitations')
          .where('invitedUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            _handleNewInvitation(change.doc);
          }
        }
      }),
    );

    // Listen for new expenses in user's groups
    for (String groupId in _userGroupIds) {
      _listenToGroupExpenses(groupId);
    }

    // Listen for new group messages
    for (String groupId in _userGroupIds) {
      _listenToGroupMessages(groupId, userId);
    }

    // Listen for direct messages
    _listenToDirectMessages(userId);

    // Listen for settlements in user's groups
    for (String groupId in _userGroupIds) {
      _listenToSettlements(groupId, userId);
    }

    // Listen for group membership changes (user added/removed)
    for (String groupId in _userGroupIds) {
      _listenToGroupMembership(groupId, userId);
    }
  }

  Future<void> _loadUserGroups(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    _userGroupIds = List<String>.from(userDoc.data()?['groupIds'] ?? []);
  }

  void _listenToGroupExpenses(String groupId) {
    _subscriptions.add(
      _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final expenseData = change.doc.data() as Map<String, dynamic>;
            final paidBy = expenseData['paidBy'] as String?;

            // Only notify if expense wasn't added by current user
            if (paidBy != _currentUserId) {
              await _handleNewExpense(groupId, expenseData);
            }
          }
        }
      }),
    );
  }

  void _listenToGroupMessages(String groupId, String userId) {
    _subscriptions.add(
      _firestore
          .collection('group_messages')
          .where('groupId', isEqualTo: groupId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final messageData = change.doc.data() as Map<String, dynamic>;
            final senderId = messageData['senderId'] as String?;

            // Only notify if message wasn't sent by current user
            if (senderId != userId) {
              // Check if user is currently viewing the chat
              final chatViewDoc = await _firestore
                  .collection('groups')
                  .doc(groupId)
                  .collection('chatViews')
                  .doc(userId)
                  .get();

              bool shouldNotify = true;
              if (chatViewDoc.exists) {
                final lastSeen = chatViewDoc.data()?['lastSeen'] as Timestamp?;
                if (lastSeen != null) {
                  final lastSeenDate = lastSeen.toDate();
                  final fiveSecondsAgo =
                      DateTime.now().subtract(const Duration(seconds: 5));
                  shouldNotify = lastSeenDate.isBefore(fiveSecondsAgo);
                }
              }

              if (shouldNotify) {
                await _handleNewGroupMessage(groupId, messageData);
              }
            }
          }
        }
      }),
    );
  }

  void _listenToDirectMessages(String userId) {
    _subscriptions.add(
      _firestore
          .collection('direct_messages')
          .where('chatId', whereIn: []) // We'll update this dynamically
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) async {
            // Get user's direct chats first
            final chatsSnapshot = await _firestore
                .collection('direct_chats')
                .where('participants', arrayContains: userId)
                .get();

            final chatIds = chatsSnapshot.docs.map((doc) => doc.id).toList();

            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final messageData = change.doc.data() as Map<String, dynamic>;
                final chatId = messageData['chatId'] as String?;
                final senderId = messageData['senderId'] as String?;

                if (chatId != null &&
                    chatIds.contains(chatId) &&
                    senderId != userId) {
                  await _handleNewDirectMessage(messageData);
                }
              }
            }
          }),
    );

    // Also listen to direct_chats to get new messages
    _subscriptions.add(
      _firestore
          .collection('direct_chats')
          .where('participants', arrayContains: userId)
          .snapshots()
          .listen((snapshot) async {
        for (var doc in snapshot.docs) {
          final chatId = doc.id;
          _listenToDirectChatMessages(chatId, userId);
        }
      }),
    );
  }

  void _listenToDirectChatMessages(String chatId, String userId) {
    _subscriptions.add(
      _firestore
          .collection('direct_messages')
          .where('chatId', isEqualTo: chatId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final messageData = change.doc.data() as Map<String, dynamic>;
            final senderId = messageData['senderId'] as String?;

            if (senderId != userId) {
              await _handleNewDirectMessage(messageData);
            }
          }
        }
      }),
    );
  }

  void _listenToSettlements(String groupId, String userId) {
    _subscriptions.add(
      _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final settlementData = change.doc.data() as Map<String, dynamic>;
            final fromUserId = settlementData['fromUserId'] as String?;
            final toUserId = settlementData['toUserId'] as String?;

            // Only notify if user is the recipient (toUserId), not the payer
            // This way you're notified when someone pays you, but not when you pay someone
            if (toUserId == userId && fromUserId != userId) {
              await _handleNewSettlement(groupId, settlementData, userId);
            }
          }
        }
      }),
    );
  }

  void _listenToGroupMembership(String groupId, String userId) {
    List<String> previousMemberIds = [];

    _subscriptions.add(
      _firestore
          .collection('groups')
          .doc(groupId)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) return;

        final groupData = snapshot.data() as Map<String, dynamic>;
        final currentMemberIds =
            List<String>.from(groupData['memberIds'] ?? []);
        final groupName = groupData['name'] as String? ?? 'Group';

        // Check if current user was just added (only notify if they didn't add themselves)
        if (currentMemberIds.contains(userId) &&
            !previousMemberIds.contains(userId)) {
          // User was added - find who added them (must be someone else)
          final members =
              List<Map<String, dynamic>>.from(groupData['members'] ?? []);
          String addedByName = 'Someone';
          String addedById = '';

          // Try to find the most recent admin or creator (excluding current user)
          for (var member in members) {
            if (member['isAdmin'] == true && member['userId'] != userId) {
              addedByName = member['username'] ?? 'Someone';
              addedById = member['userId'] ?? '';
              break;
            }
          }

          if (addedByName == 'Someone') {
            final creatorId = groupData['createdBy'] as String?;
            if (creatorId != null && creatorId != userId) {
              final creatorDoc =
                  await _firestore.collection('users').doc(creatorId).get();
              addedByName = creatorDoc.data()?['username'] ?? 'Someone';
              addedById = creatorId;
            }
          }

          // Only notify if someone else added the user (not self-join)
          if (addedById.isNotEmpty && addedById != userId) {
            await _notificationService.showUserAddedToGroupNotification(
              groupName: groupName,
              addedByName: addedByName,
            );
          }
        }

        // Check for members who left
        for (String previousMemberId in previousMemberIds) {
          if (!currentMemberIds.contains(previousMemberId) &&
              previousMemberId != userId) {
            // A member left - notify current user
            final leftUserDoc = await _firestore
                .collection('users')
                .doc(previousMemberId)
                .get();
            final leftUserName = leftUserDoc.data()?['username'] ?? 'Someone';

            await _notificationService.showUserLeftGroupNotification(
              groupName: groupName,
              leftByName: leftUserName,
            );
          }
        }

        previousMemberIds = List.from(currentMemberIds);
      }),
    );
  }

  Future<void> _handleNewInvitation(DocumentSnapshot doc) async {
    // Ignore if this document existed before we started listening
    if (_listeningStartTime != null) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final createdDate = createdAt.toDate();
          // Only process if created after we started listening (with 10 second grace period)
          // This prevents old notifications from showing when app restarts
          if (createdDate.isBefore(
              _listeningStartTime!.subtract(const Duration(seconds: 10)))) {
            return; // This is an old invitation, ignore it
          }
        }
      }
    }

    // Check if we've already processed this invitation
    final invitationId = doc.id;
    final lastProcessed = _processedInvitations[invitationId];
    if (lastProcessed != null &&
        DateTime.now().difference(lastProcessed) < const Duration(seconds: 5)) {
      return; // Already processed recently
    }
    _processedInvitations[invitationId] = DateTime.now();

    final data = doc.data() as Map<String, dynamic>;
    final groupName = data['groupName'] as String? ?? 'a group';
    final invitedByUserId =
        data['invitedByUserId'] as String? ?? data['invitedBy'] as String?;

    String inviterName = 'Someone';
    if (invitedByUserId != null) {
      final inviterDoc =
          await _firestore.collection('users').doc(invitedByUserId).get();
      inviterName = inviterDoc.data()?['username'] ?? 'Someone';
    }

    await _notificationService.showInvitationNotification(
      groupName: groupName,
      inviterName: inviterName,
    );
  }

  Future<void> _handleNewExpense(
      String groupId, Map<String, dynamic> expenseData) async {
    // Ignore if this expense existed before we started listening
    if (_listeningStartTime != null) {
      final timestamp = expenseData['timestamp'];
      if (timestamp != null && timestamp is Timestamp) {
        final expenseDate = timestamp.toDate();
        // Only process if created after we started listening (with 10 second grace period)
        if (expenseDate.isBefore(
            _listeningStartTime!.subtract(const Duration(seconds: 10)))) {
          return; // This is an old expense, ignore it
        }
      }
    }

    // Create unique key for this expense to prevent duplicates
    final timestamp = expenseData['timestamp'];
    final expenseKey =
        '${groupId}_${timestamp ?? DateTime.now().millisecondsSinceEpoch}';
    final lastProcessed = _processedExpenses[expenseKey];
    if (lastProcessed != null &&
        DateTime.now().difference(lastProcessed) < const Duration(seconds: 5)) {
      return; // Already processed recently
    }
    _processedExpenses[expenseKey] = DateTime.now();

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final groupName = groupDoc.data()?['name'] ?? 'Group';
    final description = expenseData['description'] as String? ?? 'Expense';
    final amount = (expenseData['amount'] as num?)?.toDouble() ?? 0.0;
    final paidBy = expenseData['paidBy'] as String? ?? '';

    String paidByName = 'Someone';
    if (paidBy.isNotEmpty) {
      final paidByDoc = await _firestore.collection('users').doc(paidBy).get();
      paidByName = paidByDoc.data()?['username'] ?? 'Someone';
    }

    await _notificationService.showExpenseNotification(
      groupName: groupName,
      expenseTitle: description,
      amount: amount,
      paidBy: paidByName,
    );
  }

  Future<void> _handleNewGroupMessage(
      String groupId, Map<String, dynamic> messageData) async {
    // Ignore if this message existed before we started listening
    if (_listeningStartTime != null) {
      final timestamp = messageData['timestamp'];
      if (timestamp != null && timestamp is Timestamp) {
        final messageDate = timestamp.toDate();
        // Only process if created after we started listening (with 10 second grace period)
        if (messageDate.isBefore(
            _listeningStartTime!.subtract(const Duration(seconds: 10)))) {
          return; // This is an old message, ignore it
        }
      }
    }

    // Create unique key for this message to prevent duplicates
    final timestamp = messageData['timestamp'];
    final messageKey =
        '${groupId}_${timestamp ?? DateTime.now().millisecondsSinceEpoch}';
    final lastProcessed = _processedMessages[messageKey];
    if (lastProcessed != null &&
        DateTime.now().difference(lastProcessed) < const Duration(seconds: 5)) {
      return; // Already processed recently
    }
    _processedMessages[messageKey] = DateTime.now();

    final senderName = messageData['senderName'] as String? ?? 'Someone';
    final text = messageData['text'] as String? ?? '';
    final messagePreview =
        text.length > 50 ? text.substring(0, 50) + '...' : text;

    await _notificationService.showMessageNotification(
      senderName: senderName,
      message: messagePreview,
      chatType: 'group',
    );
  }

  Future<void> _handleNewDirectMessage(Map<String, dynamic> messageData) async {
    // Ignore if this message existed before we started listening
    if (_listeningStartTime != null) {
      final timestamp = messageData['timestamp'];
      if (timestamp != null && timestamp is Timestamp) {
        final messageDate = timestamp.toDate();
        // Only process if created after we started listening (with 10 second grace period)
        if (messageDate.isBefore(
            _listeningStartTime!.subtract(const Duration(seconds: 10)))) {
          return; // This is an old message, ignore it
        }
      }
    }

    // Create unique key for this message to prevent duplicates
    final chatId = messageData['chatId'] as String? ?? '';
    final timestamp = messageData['timestamp'];
    final messageKey =
        '${chatId}_${timestamp ?? DateTime.now().millisecondsSinceEpoch}';
    final lastProcessed = _processedMessages[messageKey];
    if (lastProcessed != null &&
        DateTime.now().difference(lastProcessed) < const Duration(seconds: 5)) {
      return; // Already processed recently
    }
    _processedMessages[messageKey] = DateTime.now();

    final senderName = messageData['senderName'] as String? ?? 'Someone';
    final text = messageData['text'] as String? ?? '';
    final messagePreview =
        text.length > 50 ? text.substring(0, 50) + '...' : text;

    await _notificationService.showMessageNotification(
      senderName: senderName,
      message: messagePreview,
      chatType: 'direct',
    );
  }

  Future<void> _handleNewSettlement(String groupId,
      Map<String, dynamic> settlementData, String userId) async {
    // Ignore if this settlement existed before we started listening
    if (_listeningStartTime != null) {
      final timestamp = settlementData['timestamp'];
      if (timestamp != null && timestamp is Timestamp) {
        final settlementDate = timestamp.toDate();
        // Only process if created after we started listening (with 10 second grace period)
        if (settlementDate.isBefore(
            _listeningStartTime!.subtract(const Duration(seconds: 10)))) {
          return; // This is an old settlement, ignore it
        }
      }
    }

    // Create unique key for this settlement to prevent duplicates
    final timestamp = settlementData['timestamp'];
    final settlementKey =
        '${groupId}_${timestamp ?? DateTime.now().millisecondsSinceEpoch}';
    final lastProcessed = _processedSettlements[settlementKey];
    if (lastProcessed != null &&
        DateTime.now().difference(lastProcessed) < const Duration(seconds: 5)) {
      return; // Already processed recently
    }
    _processedSettlements[settlementKey] = DateTime.now();

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final groupName = groupDoc.data()?['name'] ?? 'Group';
    final fromUserId = settlementData['fromUserId'] as String? ?? '';
    final toUserId = settlementData['toUserId'] as String? ?? '';
    final amount = (settlementData['amount'] as num?)?.toDouble() ?? 0.0;

    String fromUserName = 'Someone';
    String toUserName = 'Someone';

    if (fromUserId.isNotEmpty) {
      final fromUserDoc =
          await _firestore.collection('users').doc(fromUserId).get();
      fromUserName = fromUserDoc.data()?['username'] ?? 'Someone';
    }

    if (toUserId.isNotEmpty) {
      final toUserDoc =
          await _firestore.collection('users').doc(toUserId).get();
      toUserName = toUserDoc.data()?['username'] ?? 'Someone';
    }

    await _notificationService.showSettlementNotification(
      groupName: groupName,
      fromUser: fromUserName,
      toUser: toUserName,
      amount: amount,
    );
  }

  Future<void> stopListening() async {
    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _currentUserId = null;
    _userGroupIds.clear();
    _listeningStartTime = null;

    // Clear processed notifications tracking
    _processedInvitations.clear();
    _processedExpenses.clear();
    _processedMessages.clear();
    _processedSettlements.clear();
  }

  Future<void> refreshUserGroups() async {
    if (_currentUserId != null) {
      await _loadUserGroups(_currentUserId!);
      // Restart listening with updated groups
      await startListening(_currentUserId!);
    }
  }
}
