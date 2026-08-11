import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'UniNav';
  static const String appSubtitle = 'University Navigation & Events';
  static const String tagline = 'Navigate • Connect • Discover';
  static const String copyright = '© 2024 University Navigator';

  // Colors
  static const Color primaryColor = Color(0xFF1A237E);
  static const Color secondaryColor = Color(0xFF3949AB);
  static const Color accentColor = Color(0xFF5E35B1);
  static const Color darkPrimaryColor = Color(0xFF283593);

  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Colors.red;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor, accentColor, darkPrimaryColor],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration splashLogoDuration = Duration(milliseconds: 1500);
  static const Duration splashTextDuration = Duration(milliseconds: 1200);
  static const Duration splashFadeDuration = Duration(milliseconds: 800);

  // Icon Sizes
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double iconXxl = 60.0;

  // Font Sizes
  static const double fontSizeXs = 10.0;
  static const double fontSizeSm = 12.0;
  static const double fontSizeMd = 14.0;
  static const double fontSizeLg = 16.0;
  static const double fontSizeXl = 18.0;
  static const double fontSizeXxl = 20.0;
  static const double fontSizeXxxl = 24.0;
  static const double fontSizeHuge = 32.0;
  static const double fontSizeMassive = 36.0;

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> logoShadow = [
    BoxShadow(
      color: Color(0x3FFFFFFF),
      blurRadius: 30,
      spreadRadius: 5,
      offset: Offset(0, 10),
    ),
  ];

  // Category Colors
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return const Color(0xFF4CAF50);
      case 'career':
        return const Color(0xFF2196F3);
      case 'social':
        return const Color(0xFFE91E63);
      case 'sports':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

class AppStrings {
  // Navigation
  static const String navDashboard = 'Dashboard';
  static const String navEvents = 'Events';
  static const String navNavigate = 'Navigate';
  static const String navProfile = 'Profile';

  // Dashboard
  static const String welcomeBack = 'Welcome back!';
  static const String quickActions = 'Quick Actions';
  static const String upcomingEvents = 'Upcoming Events';
  static const String viewAll = 'View All';

  // Events
  static const String createEvent = 'Create New Event';
  static const String eventTitle = 'Event Title';
  static const String eventDescription = 'Description';
  static const String eventDate = 'Date';
  static const String eventTime = 'Time';
  static const String eventLocation = 'Location';
  static const String eventCategory = 'Category';

  // Actions
  static const String create = 'Create';
  static const String update = 'Update';
  static const String delete = 'Delete';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String edit = 'Edit';

  // Status
  static const String loading = 'Loading...';
  static const String initializing = 'Initializing...';
  static const String noData = 'No data available';
  static const String errorOccurred = 'An error occurred';

  // Validation
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidDate = 'Please select a valid date';
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppConstants.primaryColor,
      scaffoldBackgroundColor: AppConstants.backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: AppConstants.primaryColor,
        secondary: AppConstants.secondaryColor,
        surface: AppConstants.surfaceColor,
        background: AppConstants.backgroundColor,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: AppConstants.fontSizeMassive,
          fontWeight: FontWeight.bold,
          color: AppConstants.primaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: AppConstants.fontSizeHuge,
          fontWeight: FontWeight.w600,
          color: AppConstants.primaryColor,
        ),
        titleLarge: TextStyle(
          fontSize: AppConstants.fontSizeXxl,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(
          fontSize: AppConstants.fontSizeLg,
          color: Colors.black87,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXl,
            vertical: AppConstants.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
        ),
      ),
    );
  }
}
