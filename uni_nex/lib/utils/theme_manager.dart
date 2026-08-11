import 'package:flutter/material.dart';

// App Colors
class AppColors {
  static const Color primary = Color(0xFF1A237E);
  static const Color secondary = Color(0xFF3949AB);
  static const Color accent = Color(0xFF5E35B1);
  static const Color darkPrimary = Color(0xFF283593);

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color error = Colors.red;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary, accent, darkPrimary],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

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

// App Dimensions
class AppDimensions {
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
}

// Animation Durations
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration splashLogo = Duration(milliseconds: 1500);
  static const Duration splashText = Duration(milliseconds: 1200);
  static const Duration splashFade = Duration(milliseconds: 800);
}

class ThemeManager {
  // Dynamic theme switching (for future dark mode support)
  static ThemeData getTheme({bool isDark = false}) {
    return isDark ? _darkTheme : _lightTheme;
  }

  static ThemeData get _lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: AppDimensions.fontSizeMassive,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        headlineMedium: TextStyle(
          fontSize: AppDimensions.fontSizeHuge,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        titleLarge: TextStyle(
          fontSize: AppDimensions.fontSizeXxl,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(
          fontSize: AppDimensions.fontSizeLg,
          color: Colors.black87,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingXl,
            vertical: AppDimensions.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      ),
    );
  }

  static ThemeData get _darkTheme {
    // Placeholder for dark theme - can be implemented later
    return _lightTheme.copyWith(
      brightness: Brightness.dark,
      // Add dark theme colors here when needed
    );
  }

  // Custom theme extensions for easy access
  static ColorScheme getColorScheme(BuildContext context) {
    return Theme.of(context).colorScheme;
  }

  static TextTheme getTextTheme(BuildContext context) {
    return Theme.of(context).textTheme;
  }

  // Utility methods for consistent styling
  static BoxDecoration getCardDecoration({
    Color? backgroundColor,
    double borderRadius = AppDimensions.radiusLg,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: shadows ?? AppDimensions.cardShadow,
    );
  }

  static ButtonStyle getPrimaryButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
    double borderRadius = AppDimensions.radiusMd,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: 2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingXl,
        vertical: AppDimensions.spacingMd,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static InputDecoration getTextFieldDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? borderColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.primary.withOpacity(0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.primary.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.primary,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingMd,
      ),
    );
  }
}

// Extension methods for easy theme access
extension ThemeExtensions on BuildContext {
  ColorScheme get colorScheme => ThemeManager.getColorScheme(this);
  TextTheme get textTheme => ThemeManager.getTextTheme(this);

  // Common theme helpers
  Color get primaryColor => colorScheme.primary;
  Color get secondaryColor => colorScheme.secondary;
  Color get surfaceColor => colorScheme.surface;
  Color get backgroundColor => colorScheme.background;
  Color get errorColor => colorScheme.error;

  // Spacing helpers
  double get spacingXs => AppDimensions.spacingXs;
  double get spacingSm => AppDimensions.spacingSm;
  double get spacingMd => AppDimensions.spacingMd;
  double get spacingLg => AppDimensions.spacingLg;
  double get spacingXl => AppDimensions.spacingXl;
  double get spacingXxl => AppDimensions.spacingXxl;

  // Font size helpers
  double get fontSizeXs => AppDimensions.fontSizeXs;
  double get fontSizeSm => AppDimensions.fontSizeSm;
  double get fontSizeMd => AppDimensions.fontSizeMd;
  double get fontSizeLg => AppDimensions.fontSizeLg;
  double get fontSizeXl => AppDimensions.fontSizeXl;
  double get fontSizeXxl => AppDimensions.fontSizeXxl;
}
