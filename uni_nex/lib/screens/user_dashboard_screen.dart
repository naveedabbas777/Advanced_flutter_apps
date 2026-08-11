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
import '../utils/app_router.dart';
import 'campus_navigation_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _backgroundController;
  late AnimationController _particlesController;
  late AnimationController _contentController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoBreathingAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<double> _formSlideAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _particlesAnimation;
  late Animation<double> _contentAnimation;

  UserModel? _currentUser;
  int _selectedIndex = 0;
  bool _isLoading = true;

  // User data
  List<EventModel> _upcomingEvents = [];
  List<CampusLocation> _favoriteLocations = [];
  int _registeredEventsCount = 0;

  final List<NavigationItem> _menuItems = [
    NavigationItem(
      label: 'Dashboard',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    NavigationItem(
      label: 'Events',
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note,
    ),
    NavigationItem(
      label: 'Campus Map',
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
    ),
    NavigationItem(
      label: 'My Events',
      icon: Icons.bookmark_outlined,
      activeIcon: Icons.bookmark,
    ),
    NavigationItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _loadUpcomingEvents();
    _loadFavoriteLocations();
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

    // Content animation controller
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Logo animations
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoBreathingAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: AnimationController(
          duration: const Duration(milliseconds: 2500),
          vsync: this,
        )..repeat(reverse: true),
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

    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    // Start animations sequentially
    Future.delayed(const Duration(milliseconds: 200), () {
      _logoController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
          _formController.forward().then((_) {
            _contentController.forward();
          });
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

  Future<void> _loadUpcomingEvents() async {
    try {
      final now = DateTime.now();
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('date')
          .limit(5)
          .get();

      setState(() {
        _upcomingEvents = eventsSnapshot.docs
            .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading upcoming events: $e');
    }
  }

  Future<void> _loadFavoriteLocations() async {
    try {
      if (_currentUser == null) return;

      final userPrefs = _currentUser!.preferences as Map<String, dynamic>;
      final favoriteLocations =
          userPrefs['favoriteLocations'] as List<dynamic>? ?? [];

      if (favoriteLocations.isEmpty) return;

      final locationsSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where(
            FieldPath.documentId,
            whereIn: favoriteLocations.take(5).cast<String>(),
          )
          .get();

      setState(() {
        _favoriteLocations = locationsSnapshot.docs
            .map((doc) => CampusLocation.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading favorite locations: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _formController.dispose();
    _backgroundController.dispose();
    _particlesController.dispose();
    _contentController.dispose();
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
      case 1: // Events - could show all events
        Navigator.of(context).pushNamed(AppRouter.events);
        break;
      case 2: // Campus Map
        Navigator.of(context).pushNamed(AppRouter.campusNavigation);
        break;
      case 3: // My Events - could show registered events
        Navigator.of(context).pushNamed(AppRouter.myEvents);
        break;
      case 4: // Profile - could show user profile/settings
        Navigator.of(context).pushNamed(AppRouter.profile);
        break;
    }
  }

  List<QuickActionItem> get _quickActions => [
    QuickActionItem(
      title: 'Find Events',
      subtitle: 'Discover upcoming campus events',
      icon: Icons.event,
      color: const Color(0xFF2196F3),
      onTap: () => Navigator.of(context).pushNamed(AppRouter.events),
    ),
    QuickActionItem(
      title: 'Campus Map',
      subtitle: 'Navigate around campus easily',
      icon: Icons.map,
      color: const Color(0xFF4CAF50),
      onTap: () => Navigator.of(context).pushNamed(AppRouter.campusNavigation),
    ),
    QuickActionItem(
      title: 'Quick Services',
      subtitle: 'Access campus services quickly',
      icon: Icons.room_service,
      color: const Color(0xFFFF9800),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Services feature coming soon!')),
      ),
    ),
    QuickActionItem(
      title: 'Emergency',
      subtitle: 'Quick access to emergency contacts',
      icon: Icons.emergency,
      color: const Color(0xFFF44336),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency feature coming soon!')),
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
          'Campus Hub',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        foregroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.grey[800]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon!')),
            ),
          ),
        ],
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
                    painter: UserWavePainter(
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
                    painter: UserParticlesPainter(
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
                                    color: _currentUser!.role.color.withOpacity(
                                      0.3,
                                    ),
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
                                          _currentUser!.role.color,
                                          _currentUser!.role.color.withOpacity(
                                            0.7,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _currentUser!.role.color
                                              .withOpacity(0.4),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _currentUser!.role.icon,
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
                                                  _currentUser!.role.color,
                                                  _currentUser!.role.color
                                                      .withOpacity(0.7),
                                                  Colors.white,
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
                                          'Explore campus life and stay connected',
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
                                  'Everything you need at your fingertips',
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

                    const SizedBox(height: AppDimensions.spacingXxl),

                    // Upcoming Events Section
                    AnimatedBuilder(
                      animation: _contentAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset((1 - _contentAnimation.value) * 50, 0),
                          child: Opacity(
                            opacity: _contentAnimation.value,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Upcoming Events',
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeXxl,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey[800],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'View all events coming soon!',
                                              ),
                                            ),
                                          ),
                                      child: Text(
                                        'View All',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppDimensions.spacingMd),

                                if (_upcomingEvents.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppDimensions.spacingXl,
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
                                        AppDimensions.radiusLg,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.event_busy,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(
                                            height: AppDimensions.spacingMd,
                                          ),
                                          Text(
                                            'No upcoming events',
                                            style: TextStyle(
                                              fontSize:
                                                  AppDimensions.fontSizeMd,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ..._upcomingEvents
                                      .take(2)
                                      .map(
                                        (event) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppDimensions.spacingMd,
                                          ),
                                          child: EventCard(
                                            title: event.title,
                                            date: event.date.toString().split(
                                              ' ',
                                            )[0],
                                            time: event.time,
                                            location: event.location,
                                            category: event.category,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Favorite Locations Section (if user has favorites)
                    if (_favoriteLocations.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingXxl),
                      AnimatedBuilder(
                        animation: _contentAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              (1 - _contentAnimation.value) * -50,
                              0,
                            ),
                            child: Opacity(
                              opacity: _contentAnimation.value,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Favorite Places',
                                        style: TextStyle(
                                          fontSize: AppDimensions.fontSizeXxl,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.grey[800],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          context,
                                        ).pushNamed(AppRouter.campusNavigation),
                                        child: Text(
                                          'View Map',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingMd,
                                  ),

                                  ..._favoriteLocations
                                      .take(2)
                                      .map(
                                        (location) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppDimensions.spacingMd,
                                          ),
                                          child: LocationCard(
                                            location: location,
                                            onTap: () =>
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Navigate to ${location.name} coming soon!',
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painters for user dashboard background effects
class UserWavePainter extends CustomPainter {
  final double animationValue;

  UserWavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);

    for (double x = 0; x <= size.width; x += 2) {
      final y =
          size.height * 0.5 +
          math.sin((x / size.width * 3 * math.pi) + animationValue) * 30 +
          math.sin((x / size.width * 1.5 * math.pi) + animationValue * 0.8) *
              20;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(UserWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class UserParticlesPainter extends CustomPainter {
  final double animationValue;

  UserParticlesPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Floating particles
    for (int i = 0; i < 20; i++) {
      final progress = (animationValue + i / 20.0) % 1.0;
      final x = size.width * progress;
      final y = size.height * 0.4 + math.sin(progress * 4 * math.pi) * 35;

      paint.color = AppColors.primary.withOpacity(
        0.05 + math.sin(progress * math.pi) * 0.03,
      );
      canvas.drawCircle(
        Offset(x, y),
        1.5 + math.sin(progress * math.pi),
        paint,
      );
    }

    // Gentle floating orbs
    for (int i = 0; i < 6; i++) {
      final angle = (animationValue * 0.8 * math.pi) + (i * math.pi / 3);
      final radius = 100 + i * 30;
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      paint.color = Colors.white.withOpacity(0.06);
      canvas.drawCircle(Offset(x, y), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(UserParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
