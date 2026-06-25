import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;

  late Animation<double> _sunScale;
  late Animation<double> _textOpacity;
  late Animation<double> _panelOpacity;
  late Animation<double> _beamOpacity;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _sunScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _beamOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeIn),
      ),
    );

    _panelOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 1, curve: Curves.easeOut),
      ),
    );

    _mainController.forward();

    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _rotationController]),
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF07111F),
                  Color(0xFF0E213B),
                  Color(0xFF07111F),
                ],
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: _BackgroundParticles()),

                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _sunScale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Glow
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 1, end: 1.15),
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeInOut,
                              builder: (_, double value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    width: 190,
                                    height: 190,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(.35),
                                          blurRadius: 100,
                                          spreadRadius: 30,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Rotating Rays
                            RotationTransition(
                              turns: _rotationController,
                              child: CustomPaint(
                                size: const Size(220, 220),
                                painter: SunRayPainter(),
                              ),
                            ),

                            // Sun Ring
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.orange.shade200,
                                    Colors.orange.shade700,
                                  ],
                                ),
                              ),
                            ),

                            // Inner Core
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFFFF176),
                                    Color(0xFFFFC107),
                                    Color(0xFFFF8F00),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      FadeTransition(
                        opacity: _beamOpacity,
                        child: Container(
                          width: 6,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFD54F), Color(0x00FFD54F)],
                            ),
                          ),
                        ),
                      ),

                      FadeTransition(
                        opacity: _panelOpacity,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateX(-0.55),
                          child: Container(
                            width: 220,
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFF12395D),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF4FC3F7),
                                width: 2,
                              ),
                            ),
                            child: CustomPaint(painter: SolarGridPainter()),
                          ),
                        ),
                      ),

                      const SizedBox(height: 90),

                      FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            const Text(
                              "SOLAR ALIGN PRO",
                              style: TextStyle(
                                fontSize: 30,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Professional Solar Alignment",
                              style: TextStyle(
                                color: Colors.white.withOpacity(.75),
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SunRayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF176), Color(0xFFFF9800)],
      ).createShader(Rect.fromCircle(center: center, radius: 120))
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 24; i++) {
      final angle = i * (math.pi * 2 / 24);

      final startRadius = 85.0;
      final endRadius = 125.0;

      final start = Offset(
        center.dx + math.cos(angle) * startRadius,
        center.dy + math.sin(angle) * startRadius,
      );

      final end = Offset(
        center.dx + math.cos(angle) * endRadius,
        center.dy + math.sin(angle) * endRadius,
      );

      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SolarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF81D4FA)
      ..strokeWidth = 1;

    for (int i = 1; i < 6; i++) {
      final x = size.width * i / 6;

      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _BackgroundParticles extends StatelessWidget {
  const _BackgroundParticles();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: ParticlePainter());
  }
}

class ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (int i = 0; i < 60; i++) {
      paint.color = Colors.white.withOpacity(0.15);

      canvas.drawCircle(
        Offset((i * 37 % size.width), (i * 91 % size.height)),
        1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
