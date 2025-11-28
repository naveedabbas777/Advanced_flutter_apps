// Minimal FCMService placeholder.
// This avoids introducing a required dependency on `firebase_messaging`.
// Replace with a real implementation if you add `firebase_messaging` to pubspec.
class FCMService {
  // Returns the device FCM token, or null if unavailable.
  Future<String?> getToken() async {
    // No-op placeholder. If you add `firebase_messaging`, replace this
    // implementation with `FirebaseMessaging.instance.getToken()`.
    return null;
  }
}
