import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Track recent notifications to prevent duplicates
  final Map<String, DateTime> _recentNotifications = {};
  static const Duration _duplicateWindow = Duration(minutes: 1);

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Only request notification permission - no need for exact alarms permission
      // Exact alarms permission redirects users to settings, which is not needed for regular notifications
      await androidImplementation.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    // You can navigate to specific screens based on payload
    print('Notification tapped: ${response.payload}');
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    // Create a unique key for this notification to prevent duplicates
    final notificationKey = '${title}_${body}';
    final now = DateTime.now();

    // Check if we've shown this notification recently
    if (_recentNotifications.containsKey(notificationKey)) {
      final lastShown = _recentNotifications[notificationKey]!;
      if (now.difference(lastShown) < _duplicateWindow) {
        // Duplicate notification within the time window, skip it
        return;
      }
    }

    // Record this notification
    _recentNotifications[notificationKey] = now;

    // Clean up old entries (older than duplicate window)
    _recentNotifications
        .removeWhere((key, time) => now.difference(time) > _duplicateWindow);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'split_app_channel',
      'Split App Notifications',
      channelDescription:
          'Notifications for expenses, invitations, and messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'split_app_channel',
      'Split App Notifications',
      channelDescription:
          'Notifications for expenses, invitations, and messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use inexact scheduling to avoid requiring exact alarms permission
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Helper methods for specific notification types
  Future<void> showExpenseNotification({
    required String groupName,
    required String expenseTitle,
    required double amount,
    required String paidBy,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'New Expense in $groupName',
      body: '$expenseTitle - \$${amount.toStringAsFixed(2)} paid by $paidBy',
      payload: 'expense',
    );
  }

  Future<void> showInvitationNotification({
    required String groupName,
    required String inviterName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 100000,
      title: 'Group Invitation',
      body: '$inviterName invited you to join "$groupName"',
      payload: 'invitation',
    );
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String chatType, // 'group' or 'direct'
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 200000,
      title: chatType == 'group' ? 'New Group Message' : senderName,
      body: message,
      payload: 'message',
    );
  }

  Future<void> showSettlementNotification({
    required String groupName,
    required String fromUser,
    required String toUser,
    required double amount,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 300000,
      title: 'Settlement in $groupName',
      body: '$fromUser paid \$${amount.toStringAsFixed(2)} to $toUser',
      payload: 'settlement',
    );
  }

  Future<void> showUserAddedToGroupNotification({
    required String groupName,
    required String addedByName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 400000,
      title: 'Added to Group',
      body: '$addedByName added you to "$groupName"',
      payload: 'group_added',
    );
  }

  Future<void> showUserLeftGroupNotification({
    required String groupName,
    required String leftByName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000) + 500000,
      title: 'User Left Group',
      body: '$leftByName left "$groupName"',
      payload: 'user_left',
    );
  }
}
