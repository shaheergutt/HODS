import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Logo animation
  late AnimationController _logoCtrl;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoSlideY;

  // Text animation
  late AnimationController _textCtrl;
  late Animation<double> _textFade;
  late Animation<double> _textSlideY;
  late Animation<double> _taglineFade;

  // Glow pulse animation
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  // Particles animation
  late AnimationController _particleCtrl;

  // Progress bar animation
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  // Ring rotation
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initParticles();
    _initAnimations();
    _startSequence();
  }

  void _initParticles() {
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: _random.nextDouble() * 3 + 1,
        opacity: _random.nextDouble() * 0.6 + 0.2,
        speed: _random.nextDouble() * 0.4 + 0.1,
      ));
    }
  }

  void _initAnimations() {
    // Logo controller – enters with elastic bounce
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoSlideY = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );

    // Text controller
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _textSlideY = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    // Glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Particle float
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Progress bar
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );

    // Rotating decorative ring
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _ringAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.linear),
    );
  }

  Future<void> _startSequence() async {
    // Start particles immediately
    // Logo enters at t=0
    _logoCtrl.forward();

    // Text enters after logo finishes
    await Future.delayed(const Duration(milliseconds: 700));
    _textCtrl.forward();

    // Progress bar starts
    await Future.delayed(const Duration(milliseconds: 300));
    _progressCtrl.forward();

    // Navigate after full animation
    await Future.delayed(const Duration(milliseconds: 2600));
    if (mounted) _navigate();
  }

  void _navigate() {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      context.go('/onboarding');
    } else {
      switch (user.role.name) {
        case 'student':
          context.go('/student');
          break;
        case 'owner':
          context.go('/owner');
          break;
        case 'admin':
          context.go('/admin');
          break;
      }
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _glowCtrl.dispose();
    _particleCtrl.dispose();
    _progressCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Deep gradient background ──────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0A0015),
                    Color(0xFF120B2E),
                    Color(0xFF0D0D1A),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ── Ambient glow blobs ────────────────────────────────────────────
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, _) {
              return Stack(
                children: [
                  // Top-right purple blob
                  Positioned(
                    top: -size.height * 0.12,
                    right: -size.width * 0.22,
                    child: _GlowBlob(
                      size: size.width * 0.75,
                      color: const Color(0xFF7C3AED),
                      opacity: _glowAnim.value * 0.18,
                    ),
                  ),
                  // Bottom-left blue blob
                  Positioned(
                    bottom: -size.height * 0.10,
                    left: -size.width * 0.20,
                    child: _GlowBlob(
                      size: size.width * 0.65,
                      color: const Color(0xFF3B82F6),
                      opacity: (1.0 - _glowAnim.value) * 0.14,
                    ),
                  ),
                  // Centre warm amber blob (subtle)
                  Positioned(
                    top: size.height * 0.38,
                    left: size.width * 0.15,
                    child: _GlowBlob(
                      size: size.width * 0.4,
                      color: const Color(0xFFF59E0B),
                      opacity: _glowAnim.value * 0.07,
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Floating particles ────────────────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleCtrl.value,
                ),
              );
            },
          ),

          // ── Decorative rotating dashed ring ───────────────────────────────
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (context, _) {
              return Center(
                child: Transform.rotate(
                  angle: _ringAnim.value,
                  child: CustomPaint(
                    size: const Size(280, 280),
                    painter: _DashedRingPainter(
                      color: const Color(0xFF7C3AED),
                      opacity: 0.15,
                    ),
                  ),
                ),
              );
            },
          ),

          // Counter-rotating inner ring
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (context, _) {
              return Center(
                child: Transform.rotate(
                  angle: -_ringAnim.value * 0.6,
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: _DashedRingPainter(
                      color: const Color(0xFF3B82F6),
                      opacity: 0.12,
                      dashCount: 12,
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Main content ─────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with glow + animations
                AnimatedBuilder(
                  animation: Listenable.merge([_logoCtrl, _glowAnim]),
                  builder: (context, _) {
                    return Opacity(
                      opacity: _logoFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _logoSlideY.value),
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: _LogoWidget(glowIntensity: _glowAnim.value),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),

                // App name + tagline
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _textFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlideY.value),
                        child: Column(
                          children: [
                            // App name with gradient shader
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [
                                  Color(0xFFD8B4FE),
                                  Color(0xFF7C3AED),
                                  Color(0xFF3B82F6),
                                  Color(0xFF93C5FD),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                AppStrings.appName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 8,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Tagline
                            Opacity(
                              opacity: _taglineFade.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.08),
                                ),
                                child: const Text(
                                  AppStrings.appTagline,
                                  style: TextStyle(
                                    color: Color(0xFFD8B4FE),
                                    fontSize: 12,
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.w400,
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

                const SizedBox(height: 70),

                // Animated progress bar
                AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _progressAnim.value > 0 ? 1.0 : 0.0,
                      child: Column(
                        children: [
                          // Shimmer loading bar
                          Container(
                            width: 160,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: const Color(0xFF2A2A42),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 160 * _progressAnim.value,
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C3AED),
                                      Color(0xFF3B82F6),
                                      Color(0xFFF59E0B),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: const Color(0xFF6B6C80)
                                  .withValues(alpha: _progressAnim.value),
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w400,
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

          // ── Bottom accent bar ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textCtrl,
              builder: (context, _) => Opacity(
                opacity: _taglineFade.value,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFF7C3AED),
                        Color(0xFF3B82F6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo widget ───────────────────────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  final double glowIntensity;
  const _LogoWidget({required this.glowIntensity});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35 * glowIntensity),
                blurRadius: 60,
                spreadRadius: 20,
              ),
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2 * glowIntensity),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
        // White rounded badge card
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: const LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFF8F9FA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.6 + glowIntensity * 0.2),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Image.asset(
            'assets/images/hodas_splash.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

// ── Glow blob helper ──────────────────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _GlowBlob({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.5),
            blurRadius: size * 0.4,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}

// ── Particle model ────────────────────────────────────────────────────────────
class _Particle {
  final double x;
  double y;
  final double radius;
  final double opacity;
  final double speed;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.speed,
  });
}

// ── Particle painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final yOffset = (p.y - progress * p.speed) % 1.0;
      final dy = yOffset < 0 ? yOffset + 1.0 : yOffset;

      final paint = Paint()
        ..color = const Color(0xFF7C3AED).withValues(alpha: p.opacity * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      // Alternate between purple and blue particles
      if (particles.indexOf(p).isEven) {
        paint.color = const Color(0xFF3B82F6).withValues(alpha: p.opacity * 0.6);
      }

      canvas.drawCircle(
        Offset(p.x * size.width, dy * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ── Dashed ring painter ───────────────────────────────────────────────────────
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final int dashCount;

  _DashedRingPainter({
    required this.color,
    required this.opacity,
    this.dashCount = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dashAngle = (2 * math.pi) / dashCount;
    final gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => false;
}
