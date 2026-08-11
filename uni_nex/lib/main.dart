import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/events_screen.dart';
import 'screens/user_dashboard_screen.dart';
import 'screens/home_page.dart';
import 'screens/event_management_screen.dart';
import 'screens/campus_navigation_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/my_events_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/lost_found_screen.dart';
import 'screens/lost_found_admin_screen.dart';
import 'screens/my_submissions_screen.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'utils/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(
    'pk.eyJ1IjoiYXdhaXN2ZWVyIiwiYSI6ImNtbTM3ZzNkZDBjbW4ycXNlZTU0dXNhbGUifQ.jc-drltLU8W4IG8eEJCB6Q',
  );
  runApp(const SplashApp());
}

class SplashApp extends StatefulWidget {
  const SplashApp({super.key});

  @override
  State<SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<SplashApp> {
  bool _showSplash = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize Flutter binding
      WidgetsFlutterBinding.ensureInitialized();

      debugPrint('Initializing Firebase...');
      // Initialize Firebase with default options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');

      // Mark as initialized
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Show splash for minimum 3 seconds
      await Future.delayed(const Duration(seconds: 3));

      // Now show main app
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase initialization failed: ${e.code} - ${e.message}');
      // Even if Firebase fails, continue with app
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _showSplash = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('App initialization failed: $e');
      // Even if initialization fails, show main app after splash
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _showSplash = false;
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    // After splash, if initialized, directly use _buildAuthWrapper as home
    if (_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'UniNex Campus',
        theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
        home: _buildAuthWrapper(), // Direct home to auth wrapper
        routes: _buildRoutes(),
        onGenerateRoute: _generateRoute,
      );
    }

    // Fallback during initialization (should ideally not be reached if _isInitialized is false while _showSplash is false)
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      AppRouter.login: (context) => const LoginScreen(),
      AppRouter.emailVerification: (context) => const EmailVerificationScreen(),
    };
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    if (settings.name == null || settings.name!.isEmpty) {
      debugPrint(
        'Generated route name is null or empty, redirecting to LoginScreen',
      );
      return MaterialPageRoute(builder: (context) => const LoginScreen());
    }
    // Handle authenticated routes with role checking
    return MaterialPageRoute(
      builder: (context) => _buildProtectedRoute(settings.name),
    );
  }

  Widget _buildProtectedRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      debugPrint('Route name is null or empty, redirecting to LoginScreen');
      return const LoginScreen();
    }
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        if (!user.emailVerified) {
          // Google sign-in users have their email verified by Google — skip check
          final isGoogleUser = user.providerData.any(
            (provider) => provider.providerId == 'google.com',
          );
          if (!isGoogleUser) {
            // Block unverified email/password users
            return const EmailVerificationScreen();
          }
        }

        return FutureBuilder<UserModel?>(
          future: AuthService().getUserModel(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              debugPrint('Error loading user model: ${userSnapshot.error}');
              return const LoginScreen();
            }

            final userModel = userSnapshot.data;
            if (userModel == null) {
              debugPrint('UserModel is null, redirecting to login');
              return const LoginScreen();
            }

            // Additional safety check
            if (userModel.role == null) {
              debugPrint(
                'UserModel role is null for user ${userModel.email}, using default role',
              );
              // Try to recreate user model with default role
              final fixedUserModel = UserModel(
                uid: userModel.uid,
                email: userModel.email,
                fullName: userModel.fullName,
                profileImageUrl: userModel.profileImageUrl,
                role: UserRole.user, // Default to user role
                studentId: userModel.studentId,
                department: userModel.department,
                phoneNumber: userModel.phoneNumber,
                emailVerified: userModel.emailVerified,
                isActive: userModel.isActive,
                createdAt: userModel.createdAt,
                lastLoginAt: userModel.lastLoginAt,
                updatedAt: userModel.updatedAt,
                preferences: userModel.preferences,
              );
              // Update the user in Firestore to fix the role
              AuthService().updateUserProfile(fixedUserModel);
              debugPrint('Fixed user role to default for ${userModel.email}');
            }

            // Check route-specific permissions
            switch (routeName) {
              case AppRouter.userDashboard:
                final hasAccess =
                    userModel.role == UserRole.user ||
                    userModel.role == UserRole.admin;
                debugPrint(
                  'UserDashboard access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const HomePage()
                    : _buildAccessDenied();

              case AppRouter.events:
                final hasAccess =
                    userModel.role == UserRole.user ||
                    userModel.role == UserRole.admin;
                debugPrint(
                  'Events access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const AllEventsScreen()
                    : _buildAccessDenied();

              case AppRouter.myEvents:
                final hasAccess =
                    userModel.role == UserRole.user ||
                    userModel.role == UserRole.admin;
                debugPrint(
                  'MyEvents access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const MyEventsScreen()
                    : _buildAccessDenied();

              case AppRouter.profile:
                final hasAccess =
                    userModel.role == UserRole.user ||
                    userModel.role == UserRole.admin;
                debugPrint(
                  'Profile access for ${userModel.email}: $hasAccess',
                );
                return hasAccess ? const ProfileScreen() : _buildAccessDenied();

              case AppRouter.adminDashboard:
                final hasAccess = userModel.role == UserRole.admin;
                debugPrint(
                  'AdminDashboard access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const HomePage()
                    : _buildAccessDenied();

              case AppRouter.eventManagement:
                final hasAccess = userModel.role == UserRole.admin;
                debugPrint(
                  'EventManagement access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const EventManagementScreen()
                    : _buildAccessDenied();

              case AppRouter.campusNavigation:
                final hasAccess =
                    userModel.role == UserRole.user ||
                    userModel.role == UserRole.admin;
                debugPrint(
                  'CampusNavigation access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const CampusNavigationScreen()
                    : _buildAccessDenied();

              case AppRouter.userManagement:
                final hasAccess = userModel.role == UserRole.admin;
                debugPrint(
                  'UserManagement access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const UserManagementScreen()
                    : _buildAccessDenied();

              case AppRouter.lostFound:
                final hasAccess =
                    userModel.role == UserRole.user ||
                    userModel.role == UserRole.admin;
                debugPrint(
                  'LostFound access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const LostFoundScreen()
                    : _buildAccessDenied();

              case AppRouter.lostFoundAdmin:
                final hasAccess = userModel.role == UserRole.admin;
                debugPrint(
                  'LostFoundAdmin access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const LostFoundAdminScreen()
                    : _buildAccessDenied();

              case AppRouter.mySubmissions:
                final hasAccess =
                    userModel.role == UserRole.user ||
                    userModel.role == UserRole.admin;
                debugPrint(
                  'MySubmissions access for ${userModel.email}: $hasAccess',
                );
                return hasAccess
                    ? const MySubmissionsScreen()
                    : _buildAccessDenied();

              default:
                debugPrint('Unknown route: $routeName, redirecting to login');
                return const LoginScreen();
            }
          },
        );
      },
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have permission to access this page.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthWrapper() {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          // User not logged in
          return const LoginScreen();
        }

        if (!user.emailVerified) {
          // Google sign-in users have their email verified by Google — skip check
          final isGoogleUser = user.providerData.any(
            (provider) => provider.providerId == 'google.com',
          );
          if (!isGoogleUser) {
            // Block unverified email/password users — show verification screen
            return const EmailVerificationScreen();
          }
        }

        // User is authenticated and verified, get their role
        return FutureBuilder<UserModel?>(
          future: AuthService().getUserModel(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userModel = userSnapshot.data;

            if (userModel == null) {
              // User data not found, redirect to login
              return const LoginScreen();
            }

            // Route based on user role
            if (userModel.isAdmin()) {
              return const HomePage();
            } else {
              return const HomePage();
            }
          },
        );
      },
    );
  }
}
