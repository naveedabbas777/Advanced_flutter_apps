import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Import module home screens (to be created)
import 'modules/auth/login_screen.dart';
import 'modules/products/product_list_screen.dart';
import 'modules/sales/sales_home_screen.dart';
import 'modules/sales_history/sales_history_screen.dart';
import 'modules/udhar/udhar_home_screen.dart';
import 'modules/stock/stock_home_screen.dart';
import 'modules/export_print/export_print_screen.dart';
import 'modules/settings/settings_screen.dart';
import 'modules/udhar/udhar_customer_list_screen.dart';
import 'modules/expenses/expenses_screen.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pesticide Store App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
          secondary: Colors.yellow[700]!,
          background: Colors.white,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.deepPurple,
          onBackground: Colors.deepPurple,
          onSurface: Colors.deepPurple,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            elevation: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.yellow[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.deepPurple.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.deepPurple, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.deepPurple),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.deepPurple,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class AppDashboard extends StatelessWidget {
  const AppDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<_ModuleNav> modules = [
      _ModuleNav(
        'Authentication',
        Icons.lock,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      ),
      _ModuleNav(
        'Products',
        Icons.shopping_bag,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductListScreen()),
        ),
      ),
      _ModuleNav(
        'Sales',
        Icons.point_of_sale,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesHomeScreen()),
        ),
      ),
      _ModuleNav(
        'Sales History',
        Icons.history,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
        ),
      ),
      _ModuleNav(
        'Udhar Management',
        Icons.account_balance_wallet,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UdharCustomerListScreen()),
        ),
      ),
      _ModuleNav(
        'Stock',
        Icons.inventory,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StockHomeScreen()),
        ),
      ),
      _ModuleNav(
        'Expenses',
        Icons.receipt_long,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpensesScreen()),
        ),
      ),
      _ModuleNav(
        'Settings',
        Icons.settings,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Pesticide Store Dashboard')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(24),
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            children: modules.map((m) => _ModuleCard(module: m)).toList(),
          ),
        ),
      ),
    );
  }
}

class _ModuleNav {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  _ModuleNav(this.title, this.icon, this.onTap);
}

class _ModuleCard extends StatelessWidget {
  final _ModuleNav module;
  const _ModuleCard({required this.module, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: module.onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(module.icon, size: 48, color: Colors.deepPurple),
              const SizedBox(height: 16),
              Text(
                module.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
