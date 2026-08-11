class AppRouter {
  // Authentication routes
  static const String login = '/login';
  static const String register = '/register';
  static const String emailVerification = '/email-verification';

  // Dashboard routes
  static const String userDashboard = '/user-dashboard';
  static const String adminDashboard = '/admin-dashboard';

  // Feature routes
  static const String events = '/events';
  static const String myEvents = '/my-events';
  static const String profile = '/profile';
  static const String eventManagement = '/event-management';
  static const String campusNavigation = '/campus-navigation';
  static const String userManagement = '/user-management';

  // Lost & Found routes
  static const String lostFound = '/lost-found';
  static const String lostFoundAdmin = '/lost-found-admin';
  static const String mySubmissions = '/my-submissions';

  // Legacy route (for backward compatibility)
  static const String dashboard = '/dashboard';
}
