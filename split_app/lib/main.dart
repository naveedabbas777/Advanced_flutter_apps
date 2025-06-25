import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:split_app/screens/splash_screen.dart';

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
import 'screens/expenses/edit_expense_screen.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/group_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

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
          return MaterialApp(
            title: 'Split App',
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: SplashScreen(),
            onGenerateRoute: (settings) {
              final authProvider =
                  Provider.of<AppAuthProvider>(context, listen: false);

              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => SplashScreen());
                case '/login':
                  return MaterialPageRoute(builder: (_) => LoginScreen());
                case '/home':
                  return MaterialPageRoute(builder: (_) => HomeScreen());
                case '/register':
                  return MaterialPageRoute(builder: (_) => RegisterScreen());
                case '/forgot-password':
                  return MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen());
                case '/profile':
                  return MaterialPageRoute(builder: (_) => ProfileScreen());
                case '/invitations':
                  return MaterialPageRoute(builder: (_) => InvitationsScreen());
                case '/group-details':
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => GroupDetailsScreen(
                      groupId: args['groupId'] as String,
                    ),
                  );
                case '/add-expense':
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(
                      groupId: args['groupId'] as String,
                      groupName: args['groupName'] as String,
                    ),
                  );
                case '/add-member':
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => AddMemberScreen(
                      groupId: args['groupId'] as String,
                    ),
                  );
                case '/create-group':
                  return MaterialPageRoute(builder: (_) => CreateGroupScreen());
                case '/edit-expense':
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => EditExpenseScreen(),
                    settings: settings,
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
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
