import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_strings.dart';
import '../models/event_model.dart' hide NavigationItem;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'my_events_screen.dart';
import 'profile_screen.dart';
import 'campus_navigation_screen.dart';
import 'favorite_locations_screen.dart';
import 'events_screen.dart' as events_screen;
import 'user_management_screen.dart';
import 'lost_found_screen.dart';
import 'lost_found_admin_screen.dart';
import 'my_submissions_screen.dart';
import '../widgets/navigation_drawer.dart';
import '../utils/app_router.dart';
import '../utils/theme_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  List<NavigationItem> get _navigationItems {
    final isAdmin = _currentUser?.isAdmin() ?? false;

    final items = <NavigationItem>[
      const NavigationItem(
        label: AppStrings.navDashboard,
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
      ),
      const NavigationItem(
        label: 'My Events',
        icon: Icons.bookmark_outline,
        activeIcon: Icons.bookmark,
      ),
      const NavigationItem(
        label: 'Map',
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
      ),
      const NavigationItem(
        label: 'Favorites',
        icon: Icons.favorite_border,
        activeIcon: Icons.favorite,
      ),
      const NavigationItem(
        label: 'Events',
        icon: Icons.event_outlined,
        activeIcon: Icons.event,
      ),
      const NavigationItem(
        label: 'Lost & Found',
        icon: Icons.search_outlined,
        activeIcon: Icons.search,
      ),
      const NavigationItem(
        label: 'My Submissions',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
      ),
      if (isAdmin)
        const NavigationItem(
          label: 'L&F Admin',
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
        ),
      if (isAdmin)
        const NavigationItem(
          label: 'User Management',
          icon: Icons.people_outline,
          activeIcon: Icons.people,
        ),
      const NavigationItem(
        label: AppStrings.navProfile,
        icon: Icons.person_outlined,
        activeIcon: Icons.person,
      ),
    ];

    return items;
  }

  List<Widget> get _screens {
    final isAdmin = _currentUser?.isAdmin() ?? false;

    final screens = <Widget>[
      DashboardScreen(
        onEventTap: () {
          setState(() {
            _selectedIndex = 3; // Navigate to Events screen
          });
        },
        onLocationTap: () {
          setState(() {
            _selectedIndex = 2; // Navigate to Map screen
          });
        },
      ),
      const MyEventsScreen(),
      const CampusNavigationScreen(),
      const FavoriteLocationsScreen(),
      const events_screen.AllEventsScreen(),
      const LostFoundScreen(),
      const MySubmissionsScreen(),
      if (isAdmin) const LostFoundAdminScreen(),
      if (isAdmin) const UserManagementScreen(),
      const ProfileScreen(),
    ];

    return screens;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        if (mounted) {
          setState(() => _isLoadingUser = false);
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _currentUser = UserModel.fromFirestore(doc.data()!, firebaseUser.uid);
          _isLoadingUser = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      debugPrint('Error loading home user: $e');
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  void _onDrawerItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.login),
            child: const Text('Go to Login'),
          ),
        ),
      );
    }

    final navigationItems = _navigationItems;
    final screens = _screens;
    if (_selectedIndex >= navigationItems.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      drawer: AppNavigationDrawer(
        currentUser: _currentUser!,
        currentIndex: _selectedIndex,
        onItemSelected: _onDrawerItemSelected,
        menuItems: navigationItems,
      ),
      appBar: AppBar(
        title: Text(navigationItems[_selectedIndex].label),
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.95),
        foregroundColor: Colors.grey[800],
      ),
      body: screens[_selectedIndex],
    );
  }
}
