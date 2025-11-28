# Notification Model Architecture

## Overview
This project implements a **real-time local notification system** using Firestore listeners and Flutter Local Notifications. The system automatically monitors Firestore collections and triggers notifications when relevant events occur.

---

## Architecture Components

### 1. **NotificationService** (`lib/services/notification_service.dart`)
**Purpose**: Core service for displaying local notifications on Android and iOS.

**Design Pattern**: Singleton

**Key Features**:
- Initializes notification plugin with platform-specific settings
- Requests permissions (Android 13+)
- Provides helper methods for different notification types
- Handles notification tap events

**Methods**:
```dart
- initialize()                    // Initialize the notification plugin
- showNotification()              // Generic notification display
- scheduleNotification()          // Schedule future notifications
- showExpenseNotification()      // Expense-specific notification
- showInvitationNotification()   // Invitation-specific notification
- showMessageNotification()      // Message-specific notification
- showSettlementNotification()   // Settlement-specific notification
- showUserAddedToGroupNotification()  // User added notification
- showUserLeftGroupNotification()     // User left notification
```

**Notification ID Ranges**:
- Expenses: `0 - 99,999`
- Invitations: `100,000 - 199,999`
- Messages: `200,000 - 299,999`
- Settlements: `300,000 - 399,999`
- User Added: `400,000 - 499,999`
- User Left: `500,000 - 599,999`

---

### 2. **NotificationListenerService** (`lib/services/notification_listener_service.dart`)
**Purpose**: Monitors Firestore in real-time and triggers notifications automatically.

**Design Pattern**: Singleton

**Key Features**:
- Sets up Firestore listeners for all relevant collections
- Filters notifications (doesn't notify for own actions)
- Checks if user is actively viewing chats (to avoid unnecessary notifications)
- Automatically refreshes when user groups change

**Lifecycle**:
1. **Start**: Called when user logs in
2. **Listen**: Monitors Firestore collections
3. **Stop**: Called when user logs out
4. **Refresh**: Updates listeners when groups change

**Firestore Listeners**:

#### a) Group Invitations
```dart
Collection: 'group_invitations'
Query: where('invitedUserId', isEqualTo: userId)
       where('status', isEqualTo: 'pending')
Event: New invitation added
```

#### b) Group Expenses
```dart
Collection: 'groups/{groupId}/expenses'
Query: orderBy('timestamp', descending: true).limit(1)
Event: New expense added (excludes expenses added by current user)
```

#### c) Group Messages
```dart
Collection: 'group_messages'
Query: where('groupId', isEqualTo: groupId)
       orderBy('timestamp', descending: true).limit(1)
Event: New message (excludes own messages, checks if user is viewing chat)
```

#### d) Direct Messages
```dart
Collection: 'direct_messages'
Query: where('chatId', isEqualTo: chatId)
       orderBy('timestamp', descending: true).limit(1)
Event: New direct message (excludes own messages)
```

#### e) Settlements
```dart
Collection: 'groups/{groupId}/settlements'
Query: orderBy('timestamp', descending: true).limit(1)
Event: New settlement (only if user is involved)
```

#### f) Group Membership Changes
```dart
Collection: 'groups/{groupId}'
Query: Document snapshot listener
Event: User added to group OR user left group
```

---

## Notification Types & Formats

### 1. **Expense Notifications**
```
Title: "New Expense in {groupName}"
Body: "{expenseTitle} - ${amount} paid by {paidBy}"
Payload: "expense"
Trigger: When expense is added to a group you're part of (not your own)
```

### 2. **Invitation Notifications**
```
Title: "Group Invitation"
Body: "{inviterName} invited you to join "{groupName}""
Payload: "invitation"
Trigger: When someone sends you a group invitation
```

### 3. **Message Notifications**
```
Title: "New Group Message" (for groups) OR "{senderName}" (for direct)
Body: "{messagePreview}" (truncated to 50 chars)
Payload: "message"
Trigger: When someone sends a message (not your own, and you're not actively viewing)
```

### 4. **Settlement Notifications**
```
Title: "Settlement in {groupName}"
Body: "{fromUser} paid ${amount} to {toUser}"
Payload: "settlement"
Trigger: When a settlement is created involving you
```

### 5. **User Added to Group**
```
Title: "Added to Group"
Body: "{addedByName} added you to "{groupName}""
Payload: "group_added"
Trigger: When you're added to a group
```

### 6. **User Left Group**
```
Title: "User Left Group"
Body: "{leftByName} left "{groupName}""
Payload: "user_left"
Trigger: When someone leaves a group you're part of
```

---

## Integration Points

### 1. **AuthProvider** (`lib/providers/auth_provider.dart`)
```dart
// Starts listeners on login
await NotificationListenerService().startListening(user.uid);

// Stops listeners on logout
await NotificationListenerService().stopListening();
```

### 2. **GroupProvider** (`lib/providers/group_provider.dart`)
```dart
// Refreshes listeners when groups change
await NotificationListenerService().refreshUserGroups();
```

### 3. **Main App** (`lib/main.dart`)
```dart
// Initializes notification service at app startup
await NotificationService().initialize();
```

---

## Smart Notification Logic

### 1. **Self-Action Filtering**
- ❌ No notification if you added the expense
- ❌ No notification if you sent the message
- ❌ No notification for your own invitations

### 2. **Active Chat Detection**
- Checks `chatViews/{userId}` document
- Compares `lastSeen` timestamp with current time
- Only notifies if user hasn't been active in last 5 seconds

### 3. **Group Membership Tracking**
- Tracks previous member list state
- Detects additions/removals by comparison
- Only notifies for relevant changes

---

## Data Flow

```
┌─────────────────┐
│  Firestore      │
│  Collections    │
└────────┬────────┘
         │
         │ Real-time Changes
         ▼
┌─────────────────────────┐
│ NotificationListener    │
│ Service                 │
│ - Monitors collections  │
│ - Filters events        │
│ - Checks conditions     │
└────────┬────────────────┘
         │
         │ Trigger Notification
         ▼
┌─────────────────────────┐
│ NotificationService     │
│ - Formats message       │
│ - Displays notification │
└─────────────────────────┘
```

---

## Configuration

### Android Settings
- **Channel**: `split_app_channel`
- **Importance**: High
- **Priority**: High
- **Vibration**: Enabled
- **Sound**: Enabled
- **Show When**: Enabled

### iOS Settings
- **Alert**: Enabled
- **Badge**: Enabled
- **Sound**: Enabled

---

## Dependencies

```yaml
flutter_local_notifications: ^17.2.2
timezone: ^0.9.4
cloud_firestore: ^4.17.2  # For real-time listeners
```

---

## Usage Example

```dart
// Initialize (done in main.dart)
await NotificationService().initialize();

// Start listening (done in AuthProvider on login)
await NotificationListenerService().startListening(userId);

// Manual notification (if needed)
await NotificationService().showExpenseNotification(
  groupName: "Trip to Paris",
  expenseTitle: "Hotel Booking",
  amount: 150.00,
  paidBy: "John Doe",
);
```

---

## Key Features

✅ **Real-time**: Uses Firestore snapshots for instant notifications  
✅ **Smart Filtering**: Doesn't notify for own actions  
✅ **Active Detection**: Checks if user is viewing chat  
✅ **Automatic**: No manual triggering needed  
✅ **Lifecycle Aware**: Starts/stops with user session  
✅ **Group Aware**: Automatically updates when groups change  
✅ **Cross-platform**: Works on Android and iOS  

---

## Future Enhancements

- [ ] Notification categories/channels for better organization
- [ ] Notification actions (reply, accept, reject)
- [ ] Notification grouping for multiple messages
- [ ] Custom notification sounds per type
- [ ] Notification preferences/settings screen
- [ ] Badge count management





