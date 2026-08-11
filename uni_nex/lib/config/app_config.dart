import 'package:flutter/foundation.dart';

class AppConfig {
  // App Configuration
  static const bool enableFirebase = true;
  static const bool enableOfflineMode = false;
  static const bool enableAnalytics = false;
  static const bool enableCrashlytics = false;

  // Feature Flags - Easy to toggle features on/off
  static const bool enableEvents = true;
  static const bool enableNavigation = true;
  static const bool enableCampusMap = false;
  static const bool enableNotifications = false;
  static const bool enableUserProfiles = false;
  static const bool enableDarkMode = false;

  // API Configuration
  static const String baseUrl = '';
  static const int apiTimeout = 30000; // milliseconds

  // Development Settings
  static const bool showDebugInfo = kDebugMode;
  static const bool enableLogging = kDebugMode;

  // Splash Screen Configuration
  static const int splashDuration = 3; // seconds
  static const bool skipSplashInDebug = false;

  // Navigation Configuration
  static const int maxTabs = 4;
  static const bool enableSwipeNavigation = true;

  // Cache Configuration
  static const int cacheMaxAge = 3600; // 1 hour in seconds
  static const int maxCacheSize = 100; // MB

  // Theme Configuration
  static const bool useMaterial3 = true;
  static const bool useCustomFonts = false;
  static const String fontFamily = 'Roboto';

  // Animation Configuration
  static const bool enableAnimations = true;
  static const double animationSpeed = 1.0; // 1.0 = normal speed

  // Error Handling
  static const bool showDetailedErrors = kDebugMode;
  static const bool enableErrorReporting = !kDebugMode;

  // Performance
  static const bool enablePerformanceMonitoring = false;
  static const int maxListItems = 50;
  static const bool enableLazyLoading = true;
}
