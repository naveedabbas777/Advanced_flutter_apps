import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/invitations/invitations_screen.dart';
import 'screens/expenses/add_expense_screen.dart';
import 'screens/groups/add_member_screen.dart';
import 'screens/groups/group_details_screen.dart';
import 'screens/groups/create_group_screen.dart';
import 'screens/auth/forgot_password_screen.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/group_provider.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  // You can perform heavy data processing here, like saving to local DB
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request FCM permissions and get token
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  String? token = await messaging.getToken();
  print("FCM Token: $token");
  // You might want to save this token to Firestore for the current user
  // FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).update({'fcmToken': token});

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      // Display a local notification or update UI based on the message
    }
  });

  // Handle background messages (when app is terminated or in background)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle messages when app is opened from a terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print("App opened from terminated state by message: ${message.data}");
      // Handle navigation or specific action based on the message
    }
  });

  // Handle messages when app is opened from a background state
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');
    // Handle navigation or specific action based on the message
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final authProvider = Provider.of<AppAuthProvider>(context);
          return StreamBuilder<User?>( // Listen to authentication state changes
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final _user = snapshot.data;

              return MaterialApp(
                title: 'Split App',
                theme: ThemeProvider.lightTheme,
                darkTheme: ThemeProvider.darkTheme,
                themeMode: themeProvider.themeMode,
                home: LoginScreen(), // Always show LoginScreen first
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case '/':
                      return MaterialPageRoute(builder: (_) => _user == null ? LoginScreen() : HomeScreen());
                    case '/login':
                      return MaterialPageRoute(builder: (_) => LoginScreen());
                    case '/register':
                      return MaterialPageRoute(builder: (_) => RegisterScreen());
                    case '/forgot-password':
                      return MaterialPageRoute(builder: (_) => ForgotPasswordScreen());
                    case '/profile':
                      return MaterialPageRoute(
                        builder: (_) => _user == null ? LoginScreen() : ProfileScreen(),
                      );
                    case '/invitations':
                      return MaterialPageRoute(
                        builder: (_) => _user == null ? LoginScreen() : InvitationsScreen(),
                      );
                    case '/group-details':
                      if (_user == null) return MaterialPageRoute(builder: (_) => LoginScreen());
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (_) => GroupDetailsScreen(
                          groupId: args['groupId'] as String,
                        ),
                      );
                    case '/add-expense':
                      if (_user == null) return MaterialPageRoute(builder: (_) => LoginScreen());
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (_) => AddExpenseScreen(
                          groupId: args['groupId'] as String,
                          groupName: args['groupName'] as String,
                        ),
                      );
                    case '/add-member':
                      if (_user == null) return MaterialPageRoute(builder: (_) => LoginScreen());
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (_) => AddMemberScreen(
                          groupId: args['groupId'] as String,
                        ),
                      );
                    case '/create-group':
                      return MaterialPageRoute(
                        builder: (_) => _user == null ? LoginScreen() : CreateGroupScreen(),
                      );
                    default:
                      return MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: Center(
                            child: Text('Route not found!'),
                          ),
                        ),
                      );
                  }
                },
                debugShowCheckedModeBanner: false, // Remove debug banner
              );
            },
          );
        },
      ),
    );
  }
}
