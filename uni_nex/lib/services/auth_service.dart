import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../screens/email_verification_screen.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update last login time
      if (userCredential.user != null) {
        await _updateLastLogin(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      throw e;
    }
  }

  // Register with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user != null) {
        // Create user profile in Firestore
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          email: email.trim(),
          fullName: fullName.trim(),
          role: role,
          emailVerified: false,
          isActive: true,
        );

        await _firestore
            .collection('users')
            .doc(userModel.uid)
            .set(userModel.toFirestore());

        // Send email verification
        await userCredential.user!.sendEmailVerification();
      }

      return userCredential;
    } catch (e) {
      throw e;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Always sign out previous session so account chooser is shown
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      // Trigger the Google authentication flow (account picker)
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Ensure user document exists in Firestore
      final user = userCredential.user;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          // Google-authenticated users always have verified emails
          final userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            fullName: user.displayName ?? user.email ?? '',
            role: UserRole.user,
            emailVerified: true, // Google verifies the email
            isActive: true,
          );
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(userModel.toFirestore());
        } else {
          // Update emailVerified to true for existing Google sign-in users
          final data = doc.data();
          if (data != null && data['emailVerified'] != true) {
            await _firestore.collection('users').doc(user.uid).update({
              'emailVerified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        await _updateLastLogin(user.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user model from Firestore
  Future<UserModel?> getUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final model = UserModel.fromFirestore(data, uid);

        final rawRole = (data['role'] as String?) ?? '';
        final normalizedRawRole = rawRole
            .trim()
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .replaceAll(RegExp(r'\s+'), ' ');

        // Keep Firestore role canonical for permission checks.
        if (model.isAdmin() && normalizedRawRole != 'admin') {
          await _firestore.collection('users').doc(uid).update({
            'role': 'admin',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return model;
      }
      return null;
    } catch (e) {
      print('Error getting user model: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel userModel) async {
    await _firestore
        .collection('users')
        .doc(userModel.uid)
        .update(userModel.toFirestore());
  }

  // Update last login time
  Future<void> _updateLastLogin(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if user has required role
  bool hasRole(UserModel? user, UserRole requiredRole) {
    if (user == null) return false;
    return user.role == requiredRole;
  }

  // Check if user is admin
  bool isAdmin(UserModel? user) {
    return user?.isAdmin() ?? false;
  }

  // Check if user can manage events
  bool canManageEvents(UserModel? user) {
    return user?.canManageEvents() ?? false;
  }

  // Check if user can manage locations
  bool canManageLocations(UserModel? user) {
    return user?.canManageLocations() ?? false;
  }

  // Check if user can manage users
  bool canManageUsers(UserModel? user) {
    return user?.canManageUsers() ?? false;
  }

  // Get appropriate dashboard based on user role
  String getDashboardRoute(UserModel? user) {
    if (user == null) return '/login';

    if (user.isAdmin()) {
      return '/admin-dashboard';
    } else {
      return '/user-dashboard';
    }
  }
}

// Authentication guard widget
class AuthGuard extends StatelessWidget {
  final Widget child;
  final UserRole? requiredRole;
  final Widget? fallbackWidget;

  const AuthGuard({
    super.key,
    required this.child,
    this.requiredRole,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return fallbackWidget ?? const LoginScreen();
        }

        if (!user.emailVerified) {
          // Google sign-in users have their email verified by Google
          final isGoogleUser = user.providerData.any(
            (provider) => provider.providerId == 'google.com',
          );
          if (!isGoogleUser) {
            return const EmailVerificationScreen();
          }
        }

        // If no role requirement, allow access
        if (requiredRole == null) {
          return child;
        }

        // Check role requirement
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return fallbackWidget ?? (const LoginScreen() as Widget);
            }

            final userModel = UserModel.fromFirestore(
              userSnapshot.data!.data() as Map<String, dynamic>,
              user.uid,
            );

            final hasAccess = AuthService().hasRole(userModel, requiredRole!);
            if (!hasAccess) {
              return fallbackWidget ??
                  Scaffold(
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
                          Text(
                            'You don\'t have permission to access this page.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pushReplacementNamed('/'),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  );
            }

            return child;
          },
        );
      },
    );
  }
}

// Role-based route guard
class RoleGuard extends StatelessWidget {
  final Widget child;
  final UserRole requiredRole;
  final String? redirectRoute;

  const RoleGuard({
    super.key,
    required this.child,
    required this.requiredRole,
    this.redirectRoute,
  });

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      requiredRole: requiredRole,
      child: child,
      fallbackWidget: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '${requiredRole.displayName} Access Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This page requires ${requiredRole.displayName.toLowerCase()} privileges.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
