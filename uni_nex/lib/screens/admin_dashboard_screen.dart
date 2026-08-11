import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/event_model.dart' hide NavigationItem;
import '../models/campus_location_model.dart';
import '../widgets/navigation_drawer.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/event_card.dart';
import '../widgets/location_card.dart';
import '../utils/theme_manager.dart';
import '../services/firebase_service.dart';
import '../utils/app_router.dart';
import 'event_management_screen.dart';
import 'campus_navigation_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _backgroundController;
  late AnimationController _particlesController;
  late AnimationController _statsController;
  late AnimationController _breathingController; // Declared here

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoBreathingAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<double> _formSlideAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _particlesAnimation;
  late Animation<double> _statsAnimation;

  UserModel? _currentUser;
  int _selectedIndex = 0;
  bool _isLoading = true;

  // Stats data
  int _totalEvents = 0;
  int _totalLocations = 0;
  int _totalUsers = 0;
  int _activeEvents = 0;

  final List<NavigationItem> _menuItems = [
    NavigationItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    NavigationItem(
      label: 'Event Management',
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note,
    ),
    NavigationItem(
      label: 'Campus Navigation',
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
    ),
    NavigationItem(
      label: 'User Management',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    NavigationItem(
      label: 'Analytics',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _loadStats();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Form animation controller
    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Background animation controller
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    )..repeat();

    // Particles animation controller
    _particlesController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();

    // Stats animation controller
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Breathing animation controller (initialized here)
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    // Logo animations
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoBreathingAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathingController, // Use the new controller here
        curve: Curves.easeInOut,
      ),
    );

    // Form animations
    _formFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOut));

    _formSlideAnimation = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutBack),
    );

    // Background animations
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_backgroundController);

    _particlesAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particlesController);

    _statsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _statsController, curve: Curves.easeOut));

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 200), () {
      _logoController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
          _formController.forward();
        });
      });
    });
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _currentUser = UserModel.fromFirestore(userDoc.data()!, user.uid);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      // Get total events
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();
      _totalEvents = eventsSnapshot.docs.length;

      // Get active events (events in the future)
      final now = DateTime.now();
      _activeEvents = eventsSnapshot.docs.where((doc) {
        final data = doc.data();
        final eventDate = (data['date'] as Timestamp?)?.toDate();
        return eventDate != null && eventDate.isAfter(now);
      }).length;

      // Get total locations
      final locationsSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .get();
      _totalLocations = locationsSnapshot.docs.length;

      // Get total users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      _totalUsers = usersSnapshot.docs.length;

      setState(() {});
      _statsController.forward();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _formController.dispose();
    _backgroundController.dispose();
    _particlesController.dispose();
    _statsController.dispose();
    _breathingController.dispose(); // Dispose the breathing controller
    super.dispose();
  }

  void _onNavigationItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation based on selected index
    switch (index) {
      case 0: // Dashboard - already here
        break;
      case 1: // Event Management
        Navigator.of(context).pushNamed(AppRouter.eventManagement);
        break;
      case 2: // Campus Navigation
        Navigator.of(context).pushNamed(AppRouter.campusNavigation);
        break;
      case 3: // User Management
        Navigator.of(context).pushNamed(AppRouter.userManagement);
        break;
      case 4: // Analytics - could be implemented later
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analytics feature coming soon!')),
        );
        break;
    }
  }

  List<QuickActionItem> get _quickActions => [
    QuickActionItem(
      title: 'Manage Events',
      subtitle: 'Create, edit, and manage campus events',
      icon: Icons.event_note,
      color: const Color(0xFF2196F3),
      onTap: () => Navigator.of(context).pushNamed(AppRouter.eventManagement),
    ),
    QuickActionItem(
      title: 'Campus Locations',
      subtitle: 'Add and manage campus locations',
      icon: Icons.map,
      color: const Color(0xFF4CAF50),
      onTap: () => Navigator.of(context).pushNamed(AppRouter.campusNavigation),
    ),
    QuickActionItem(
      title: 'User Management',
      subtitle: 'Manage user roles and permissions',
      icon: Icons.people,
      color: const Color(0xFFFF9800),
      onTap: () => Navigator.of(context).pushNamed(AppRouter.userManagement),
    ),
    QuickActionItem(
      title: 'System Settings',
      subtitle: 'Configure app settings and preferences',
      icon: Icons.settings,
      color: const Color(0xFF9C27B0),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings feature coming soon!')),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        foregroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      drawer: AppNavigationDrawer(
        currentUser: _currentUser!,
        currentIndex: _selectedIndex,
        onItemSelected: _onNavigationItemSelected,
        menuItems: _menuItems,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE3F2FD),
              const Color(0xFFF8F9FA),
              Colors.white,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated wave background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _backgroundAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AdminWavePainter(
                      animationValue: _backgroundAnimation.value,
                    ),
                  );
                },
              ),
            ),

            // Floating particles
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particlesAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AdminParticlesPainter(
                      animationValue: _particlesAnimation.value,
                    ),
                  );
                },
              ),
            ),

            // Main content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spacingXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _logoController,
                        _logoBreathingAnimation,
                      ]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale:
                              _logoScaleAnimation.value *
                              _logoBreathingAnimation.value,
                          child: Transform.rotate(
                            angle: _logoRotationAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(
                                AppDimensions.spacingLg,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.9),
                                    Colors.white.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusXl,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 50,
                                    spreadRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primary,
                                          AppColors.secondary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(
                                            0.4,
                                          ),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: AppDimensions.spacingMd,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) =>
                                              LinearGradient(
                                                colors: [
                                                  AppColors.primary,
                                                  AppColors.secondary,
                                                  AppColors.accent,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(bounds),
                                          child: Text(
                                            _currentUser!.getGreeting(),
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppDimensions.spacingXs,
                                        ),
                                        Text(
                                          'Manage your campus ecosystem efficiently',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppDimensions.spacingXxl),

                    // Stats Cards
                    AnimatedBuilder(
                      animation: _statsAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, (1 - _statsAnimation.value) * 30),
                          child: Opacity(
                            opacity: _statsAnimation.value,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Total Events',
                                    _totalEvents.toString(),
                                    Icons.event,
                                    const Color(0xFF2196F3),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacingMd),
                                Expanded(
                                  child: _buildStatCard(
                                    'Active Events',
                                    _activeEvents.toString(),
                                    Icons.event_available,
                                    const Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppDimensions.spacingMd),

                    AnimatedBuilder(
                      animation: _statsAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, (1 - _statsAnimation.value) * 30),
                          child: Opacity(
                            opacity: _statsAnimation.value,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Campus Locations',
                                    _totalLocations.toString(),
                                    Icons.location_on,
                                    const Color(0xFFFF9800),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacingMd),
                                Expanded(
                                  child: _buildStatCard(
                                    'Total Users',
                                    _totalUsers.toString(),
                                    Icons.people,
                                    const Color(0xFF9C27B0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppDimensions.spacingXxl),

                    // Quick Actions
                    AnimatedBuilder(
                      animation: _formController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _formSlideAnimation.value),
                          child: Opacity(
                            opacity: _formFadeAnimation.value,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Actions',
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeXxl,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey[800],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacingMd),
                                Text(
                                  'Manage your campus resources with ease',
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeMd,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacingLg),

                                // Quick Action Cards
                                ..._quickActions.map(
                                  (action) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppDimensions.spacingMd,
                                    ),
                                    child: QuickActionCard(item: action),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 15,
            spreadRadius: -3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingSm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: AppDimensions.iconLg),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            value,
            style: TextStyle(
              fontSize: AppDimensions.fontSizeXxl,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            title,
            style: TextStyle(
              fontSize: AppDimensions.fontSizeSm,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Custom painters for admin dashboard background effects
class AdminWavePainter extends CustomPainter {
  final double animationValue;

  AdminWavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.4);

    for (double x = 0; x <= size.width; x += 2) {
      final y =
          size.height * 0.4 +
          math.sin((x / size.width * 4 * math.pi) + animationValue) * 35 +
          math.sin((x / size.width * 2 * math.pi) + animationValue * 0.7) * 20;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AdminWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class AdminParticlesPainter extends CustomPainter {
  final double animationValue;

  AdminParticlesPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Floating particles
    for (int i = 0; i < 25; i++) {
      final progress = (animationValue + i / 25.0) % 1.0;
      final x = size.width * progress;
      final y = size.height * 0.2 + math.sin(progress * 5 * math.pi) * 40;

      paint.color = AppColors.primary.withOpacity(
        0.04 + math.sin(progress * math.pi) * 0.02,
      );
      canvas.drawCircle(
        Offset(x, y),
        1.8 + math.sin(progress * math.pi) * 0.5,
        paint,
      );
    }

    // Orbital particles
    for (int i = 0; i < 10; i++) {
      final angle = (animationValue * 1.2 * math.pi) + (i * math.pi / 5);
      final radius = 140 + i * 25;
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      paint.color = Colors.white.withOpacity(0.08);
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(AdminParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
