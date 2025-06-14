import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/groups/create_group_screen.dart';
import 'screens/groups/group_details_screen.dart';
import 'screens/expenses/add_expense_screen.dart';
import 'screens/groups/add_member_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(MyApp());
  } catch (e) {
    print('Error initializing Firebase: $e');
    // You might want to show an error screen here
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app. Please try again later.'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Split App',
            theme: themeProvider.currentTheme,
            home: Consumer<AppAuthProvider>(
              builder: (context, authProvider, child) {
                if (authProvider.isLoading) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return authProvider.user != null
                    ? HomeScreen()
                    : LoginScreen();
              },
            ),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => HomeScreen());
                case '/login':
                  return MaterialPageRoute(builder: (_) => LoginScreen());
                case '/register':
                  return MaterialPageRoute(builder: (_) => RegisterScreen());
                case '/profile':
                  return MaterialPageRoute(builder: (_) => ProfileScreen());
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
          );
        },
      ),
    );
  }
}
