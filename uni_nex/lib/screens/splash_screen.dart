import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/theme_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  late AnimationController _breathingController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  late AnimationController _glowController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoBreathingAnimation;
  late Animation<double> _logoGlowAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _loadingFadeAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      duration: AppAnimations.splashLogo,
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: AppAnimations.splashText,
      vsync: this,
    );

    // Loading animation controller
    _loadingController = AnimationController(
      duration: AppAnimations.splashFade,
      vsync: this,
    );

    // Breathing effect controller (soothing pulse)
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    // Wave animation controller
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    )..repeat();

    // Particle animation controller
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();

    // Glow animation controller
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Logo animations
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.8, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoBreathingAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _logoGlowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Text animations
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _textSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutBack),
    );

    // Loading fade animation
    _loadingFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeIn),
    );

    // Wave and particle animations
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_waveController);

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particleController);

    // Start animations with staggered timing
    Future.delayed(const Duration(milliseconds: 300), () {
      _logoController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _textController.forward().then((_) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _loadingController.forward();
            });
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _breathingController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D47A1), // Deep blue
              const Color(0xFF1565C0), // Blue
              const Color(0xFF1976D2), // Light blue
              const Color(0xFF1E88E5), // Lighter blue
              const Color(0xFF42A5F5), // Very light blue
              const Color(0xFFE3F2FD), // Very light blue background
            ],
            stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated wave background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _waveAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(
                      animationValue: _waveAnimation.value,
                      color: Colors.white.withOpacity(0.03),
                    ),
                  );
                },
              ),
            ),

            // Advanced particle system
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AdvancedParticlePainter(
                      animationValue: _particleAnimation.value,
                    ),
                  );
                },
              ),
            ),

            // Floating geometric shapes
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: GeometricShapesPainter(
                      animationValue: _particleController.value,
                    ),
                  );
                },
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo/Icon with breathing effect
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _logoController,
                      _breathingController,
                      _glowController,
                    ]),
                    builder: (context, child) {
                      final combinedScale =
                          _logoScaleAnimation.value *
                          _logoBreathingAnimation.value;

                      return Transform.scale(
                        scale: combinedScale,
                        child: Transform.rotate(
                          angle: _logoRotationAnimation.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.9),
                                  Colors.white.withOpacity(0.8),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(
                                    _logoGlowAnimation.value,
                                  ),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(
                                    _logoGlowAnimation.value * 0.5,
                                  ),
                                  blurRadius: 70,
                                  spreadRadius: 15,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.school,
                              size: 75,
                              color: AppColors.primary,
                              shadows: [
                                Shadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 50),

                  // Animated App name with enhanced typography
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlideAnimation.value),
                        child: Opacity(
                          opacity: _textFadeAnimation.value,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.8),
                                Colors.white.withOpacity(0.9),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: Text(
                              'UniNav',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 3,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  Shadow(
                                    color: AppColors.primary.withOpacity(0.6),
                                    blurRadius: 30,
                                    offset: const Offset(0, 4),
                                  ),
                                  Shadow(
                                    color: AppColors.accent.withOpacity(0.4),
                                    blurRadius: 40,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Animated Subtitle with glassmorphism effect
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlideAnimation.value * 0.5),
                        child: Opacity(
                          opacity: _textFadeAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'University Navigation & Events',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.8,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 70),

                  // Animated Loading indicator with creative design
                  AnimatedBuilder(
                    animation: _loadingController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _loadingFadeAnimation.value,
                        child: Column(
                          children: [
                            // Creative loading container
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.9),
                                  ),
                                  strokeWidth: 3,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Animated dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return AnimatedBuilder(
                                  animation: _loadingController,
                                  builder: (context, child) {
                                    final delay = index * 0.2;
                                    final opacity = math
                                        .sin(
                                          (_loadingController.value *
                                                  2 *
                                                  math.pi) +
                                              delay,
                                        )
                                        .abs();
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(
                                          opacity * 0.8,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              'Initializing...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for soothing wave background
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);

    for (double x = 0; x <= size.width; x += 2) {
      final y =
          size.height * 0.7 +
          math.sin((x / size.width * 4 * math.pi) + animationValue) * 30 +
          math.sin((x / size.width * 2 * math.pi) + animationValue * 0.5) * 20;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Advanced particle system with organic movement
class AdvancedParticlePainter extends CustomPainter {
  final double animationValue;

  AdvancedParticlePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Create multiple particle systems
    _drawFloatingParticles(canvas, size);
    _drawSparkleParticles(canvas, size);
    _drawOrbitalParticles(canvas, size);
  }

  void _drawFloatingParticles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final progress = (animationValue + i / 12) % 1.0;
      final x = size.width * progress;
      final y = size.height * 0.3 + math.sin(progress * 4 * math.pi) * 50;

      paint.color = Colors.white.withOpacity(
        0.08 + math.sin(progress * math.pi) * 0.05,
      );
      canvas.drawCircle(
        Offset(x, y),
        3 + math.sin(progress * math.pi) * 2,
        paint,
      );
    }
  }

  void _drawSparkleParticles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (animationValue * 2 * math.pi) + (i * math.pi / 4);
      final radius = 80 + i * 20;
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      paint.color = Colors.white.withOpacity(0.06);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  void _drawOrbitalParticles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final angle = animationValue * 2 * math.pi + i * math.pi / 3;
      final radius = 120 + i * 30;
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      paint.color = AppColors.primary.withOpacity(0.03);
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(AdvancedParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Geometric shapes painter for creative floating elements
class GeometricShapesPainter extends CustomPainter {
  final double animationValue;

  GeometricShapesPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;

    // Draw floating triangles
    for (int i = 0; i < 4; i++) {
      final progress = (animationValue + i / 4) % 1.0;
      final x = size.width * (0.1 + progress * 0.8);
      final y = size.height * (0.2 + math.sin(progress * 2 * math.pi) * 0.2);

      paint.color = Colors.white.withOpacity(0.04);
      paint.strokeWidth = 1.5;

      final path = Path();
      path.moveTo(x, y - 15);
      path.lineTo(x - 12, y + 10);
      path.lineTo(x + 12, y + 10);
      path.close();
      canvas.drawPath(path, paint);
    }

    // Draw floating circles
    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i / 3) % 1.0;
      final x = size.width * (0.9 - progress * 0.6);
      final y = size.height * (0.8 - math.cos(progress * 3 * math.pi) * 0.15);

      paint.color = AppColors.accent.withOpacity(0.03);
      paint.strokeWidth = 1;
      canvas.drawCircle(Offset(x, y), 8, paint);
    }

    // Draw floating squares
    for (int i = 0; i < 2; i++) {
      final progress = (animationValue + i / 2) % 1.0;
      final x = size.width * (0.3 + progress * 0.4);
      final y = size.height * (0.6 + math.sin(progress * 4 * math.pi) * 0.1);

      paint.color = Colors.white.withOpacity(0.03);
      paint.strokeWidth = 1;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 16, height: 16),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GeometricShapesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
