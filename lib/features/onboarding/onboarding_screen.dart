import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────────────────────────────────────
class _PageData {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final List<Color> accentColors;
  final _IllustrationBuilder illustrationBuilder;

  const _PageData({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColors,
    required this.illustrationBuilder,
  });
}

typedef _IllustrationBuilder = Widget Function(
    BuildContext context, Animation<double> pulse, Animation<double> float);

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  // Animations
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  late AnimationController _particleCtrl;

  late AnimationController _contentCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  late AnimationController _bgCtrl;

  final _random = math.Random(42);
  final List<_ParticleDot> _dots = [];

  late final List<_PageData> _pages;

  @override
  void initState() {
    super.initState();
    _buildPages();
    _initDots();
    _initAnimations();
  }

  void _buildPages() {
    _pages = [
      _PageData(
        title: 'Find Your Perfect\nHostel',
        subtitle:
            'Browse hundreds of verified hostels across Pakistan. Filter by city, facilities, and budget to find your ideal home.',
        gradientColors: const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        accentColors: const [Color(0xFFD8B4FE), Color(0xFF818CF8)],
        illustrationBuilder: _buildHostelIllustration,
      ),
      _PageData(
        title: 'AI-Powered\nRecommendations',
        subtitle:
            'Our smart AI engine recommends the best hostels based on your location, preferences, and budget — personalized just for you.',
        gradientColors: const [Color(0xFF0891B2), Color(0xFF4F46E5)],
        accentColors: const [Color(0xFF67E8F9), Color(0xFFA5B4FC)],
        illustrationBuilder: _buildAIIllustration,
      ),
      _PageData(
        title: 'Verified &\nLicensed Owners',
        subtitle:
            'Every hostel owner is verified and licensed by HODS admin — ensuring your safety, comfort, and quality of stay.',
        gradientColors: const [Color(0xFF059669), Color(0xFF0891B2)],
        accentColors: const [Color(0xFF6EE7B7), Color(0xFF67E8F9)],
        illustrationBuilder: _buildVerifiedIllustration,
      ),
    ];
  }

  void _initDots() {
    for (int i = 0; i < 28; i++) {
      _dots.add(_ParticleDot(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        r: _random.nextDouble() * 2.5 + 0.8,
        opacity: _random.nextDouble() * 0.5 + 0.15,
        speed: _random.nextDouble() * 0.3 + 0.08,
        phase: _random.nextDouble() * math.pi * 2,
      ));
    }
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -14.0, end: 14.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _contentCtrl.forward();
  }

  Future<void> _onPageChanged(int i) async {
    setState(() => _currentPage = i);
    _contentCtrl.reset();
    _contentCtrl.forward();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/role-select');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    _contentCtrl.dispose();
    _bgCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Animated gradient background ─────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  page.gradientColors.first.withValues(alpha: 0.18),
                  AppColors.background,
                  page.gradientColors.last.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Floating particles ───────────────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _FloatingParticlePainter(
                dots: _dots,
                progress: _particleCtrl.value,
                color: page.accentColors.first,
              ),
            ),
          ),

          // ── Ambient glow orbs ────────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) {
              return Stack(children: [
                Positioned(
                  top: -size.height * 0.06,
                  right: -size.width * 0.18,
                  child: _GlowOrb(
                    size: size.width * 0.7,
                    color: page.gradientColors.first,
                    opacity: 0.13 * _pulseAnim.value,
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.1,
                  left: -size.width * 0.22,
                  child: _GlowOrb(
                    size: size.width * 0.6,
                    color: page.gradientColors.last,
                    opacity: 0.10 * (2.0 - _pulseAnim.value),
                  ),
                ),
              ]);
            },
          ),

          // ── Page content ─────────────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => _PageContent(
              data: _pages[i],
              pulseAnim: _pulseAnim,
              floatAnim: _floatAnim,
              contentFade: _contentFade,
              contentSlide: _contentSlide,
              isActive: i == _currentPage,
            ),
          ),

          // ── Bottom controls ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomControls(
              currentPage: _currentPage,
              totalPages: _pages.length,
              accentColor: page.gradientColors.first,
              onNext: _nextPage,
              onSkip: () => context.go('/role-select'),
              isLast: _currentPage == _pages.length - 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Content Widget
// ─────────────────────────────────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final _PageData data;
  final Animation<double> pulseAnim;
  final Animation<double> floatAnim;
  final Animation<double> contentFade;
  final Animation<Offset> contentSlide;
  final bool isActive;

  const _PageContent({
    required this.data,
    required this.pulseAnim,
    required this.floatAnim,
    required this.contentFade,
    required this.contentSlide,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        // Illustration area
        SizedBox(
          height: size.height * 0.52,
          width: double.infinity,
          child: data.illustrationBuilder(context, pulseAnim, floatAnim),
        ),

        // Text area
        Expanded(
          child: FadeTransition(
            opacity: contentFade,
            child: SlideTransition(
              position: contentSlide,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Accent chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color:
                            data.gradientColors.first.withValues(alpha: 0.15),
                        border: Border.all(
                          color:
                              data.gradientColors.first.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'HODS Platform',
                        style: TextStyle(
                          color: data.accentColors.first,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          data.accentColors.first,
                          AppColors.textPrimary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        data.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Subtitle
                    Text(
                      data.subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.5,
                        height: 1.65,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Space for bottom controls
        const SizedBox(height: 150),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Controls
// ─────────────────────────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color accentColor;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.accentColor,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 44),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.background.withValues(alpha: 0.0),
            AppColors.background.withValues(alpha: 0.97),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (i) {
              final isActive = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                width: isActive ? 32 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? accentColor
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // Next / Get Started button
          GestureDetector(
            onTap: onNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: isLast
                      ? [accentColor, accentColor.withValues(alpha: 0.7)]
                      : [accentColor, accentColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Get Started' : 'Continue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Skip button
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textHint,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text(
              'Skip for now',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration 1 — Find Hostel
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildHostelIllustration(
    BuildContext context, Animation<double> pulse, Animation<double> float) {
  return AnimatedBuilder(
    animation: Listenable.merge([pulse, float]),
    builder: (_, __) {
      final floatY = float.value;
      return Stack(
        alignment: Alignment.center,
        children: [
          // Big glow ring
          Transform.scale(
            scale: pulse.value,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Outer dashed ring (custom paint)
          Transform.rotate(
            angle: pulse.value * 0.4,
            child: CustomPaint(
              size: const Size(260, 260),
              painter: _DashedCirclePainter(
                color: const Color(0xFF7C3AED),
                opacity: 0.25,
                dashCount: 20,
              ),
            ),
          ),

          // Floating building card
          Transform.translate(
            offset: Offset(0, floatY),
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1040), Color(0xFF120B2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apartment_rounded,
                      size: 72, color: Color(0xFFD8B4FE)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    ),
                    child: const Text(
                      '240+ Hostels',
                      style: TextStyle(
                        color: Color(0xFFD8B4FE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top-right floating chip
          Positioned(
            top: 60,
            right: 36,
            child: Transform.translate(
              offset: Offset(0, -floatY * 0.6),
              child: _FloatingChip(
                icon: Icons.location_on_rounded,
                label: 'Islamabad',
                color: const Color(0xFF3B82F6),
              ),
            ),
          ),

          // Bottom-left floating chip
          Positioned(
            bottom: 62,
            left: 36,
            child: Transform.translate(
              offset: Offset(0, floatY * 0.7),
              child: _FloatingChip(
                icon: Icons.star_rounded,
                label: '4.8 Rating',
                color: const Color(0xFFF59E0B),
              ),
            ),
          ),

          // Top-left small badge
          Positioned(
            top: 90,
            left: 42,
            child: Transform.translate(
              offset: Offset(0, floatY * 0.5),
              child: _FloatingChip(
                icon: Icons.wifi_rounded,
                label: 'WiFi',
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration 2 — AI
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildAIIllustration(
    BuildContext context, Animation<double> pulse, Animation<double> float) {
  return AnimatedBuilder(
    animation: Listenable.merge([pulse, float]),
    builder: (_, __) {
      final floatY = float.value;
      return Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer glow
          Transform.scale(
            scale: pulse.value,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0891B2).withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Rotating rings
          Transform.rotate(
            angle: -pulse.value * 0.5,
            child: CustomPaint(
              size: const Size(265, 265),
              painter: _DashedCirclePainter(
                color: const Color(0xFF0891B2),
                opacity: 0.22,
                dashCount: 16,
              ),
            ),
          ),
          Transform.rotate(
            angle: pulse.value * 0.3,
            child: CustomPaint(
              size: const Size(220, 220),
              painter: _DashedCirclePainter(
                color: const Color(0xFF4F46E5),
                opacity: 0.18,
                dashCount: 12,
              ),
            ),
          ),

          // Central AI card
          Transform.translate(
            offset: Offset(0, floatY),
            child: Container(
              width: 185,
              height: 185,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1628), Color(0xFF0D1B2A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF0891B2).withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0891B2).withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology_rounded,
                      size: 70, color: Color(0xFF67E8F9)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF0891B2).withValues(alpha: 0.22),
                    ),
                    child: const Text(
                      'Smart AI Engine',
                      style: TextStyle(
                        color: Color(0xFF67E8F9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating orbit dots
          ..._orbitChips(pulse.value, floatY),
        ],
      );
    },
  );
}

List<Widget> _orbitChips(double pulse, double floatY) {
  return [
    Positioned(
      top: 55,
      right: 30,
      child: Transform.translate(
        offset: Offset(0, -floatY * 0.55),
        child: _FloatingChip(
          icon: Icons.tune_rounded,
          label: 'Personalized',
          color: const Color(0xFF818CF8),
        ),
      ),
    ),
    Positioned(
      bottom: 55,
      left: 28,
      child: Transform.translate(
        offset: Offset(0, floatY * 0.65),
        child: _FloatingChip(
          icon: Icons.bolt_rounded,
          label: 'Instant Match',
          color: const Color(0xFFF59E0B),
        ),
      ),
    ),
    Positioned(
      top: 105,
      left: 34,
      child: Transform.translate(
        offset: Offset(0, floatY * 0.45),
        child: _FloatingChip(
          icon: Icons.insights_rounded,
          label: 'Smart',
          color: const Color(0xFF10B981),
        ),
      ),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration 3 — Verified
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildVerifiedIllustration(
    BuildContext context, Animation<double> pulse, Animation<double> float) {
  return AnimatedBuilder(
    animation: Listenable.merge([pulse, float]),
    builder: (_, __) {
      final floatY = float.value;
      return Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing glow
          Transform.scale(
            scale: pulse.value,
            child: Container(
              width: 285,
              height: 285,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF059669).withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Rotating rings
          Transform.rotate(
            angle: pulse.value * 0.45,
            child: CustomPaint(
              size: const Size(262, 262),
              painter: _DashedCirclePainter(
                color: const Color(0xFF059669),
                opacity: 0.22,
                dashCount: 18,
              ),
            ),
          ),

          // Central shield card
          Transform.translate(
            offset: Offset(0, floatY),
            child: Container(
              width: 188,
              height: 188,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  colors: [Color(0xFF061A12), Color(0xFF0A1F18)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF059669).withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 72, color: Color(0xFF6EE7B7)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF059669).withValues(alpha: 0.22),
                    ),
                    child: const Text(
                      'HODS Certified',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating badges
          Positioned(
            top: 58,
            right: 28,
            child: Transform.translate(
              offset: Offset(0, -floatY * 0.6),
              child: _FloatingChip(
                icon: Icons.shield_rounded,
                label: 'Licensed',
                color: const Color(0xFF059669),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 30,
            child: Transform.translate(
              offset: Offset(0, floatY * 0.7),
              child: _FloatingChip(
                icon: Icons.security_rounded,
                label: 'Safe & Secure',
                color: const Color(0xFF0891B2),
              ),
            ),
          ),
          Positioned(
            top: 108,
            left: 36,
            child: Transform.translate(
              offset: Offset(0, floatY * 0.45),
              child: _FloatingChip(
                icon: Icons.check_circle_rounded,
                label: 'Verified',
                color: const Color(0xFF6EE7B7),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Chip Widget
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FloatingChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.cardColor,
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glow Orb Widget
// ─────────────────────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
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
            color: color.withValues(alpha: opacity * 0.6),
            blurRadius: size * 0.45,
            spreadRadius: size * 0.08,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Particle Dot Model
// ─────────────────────────────────────────────────────────────────────────────
class _ParticleDot {
  final double x, y, r, opacity, speed, phase;
  _ParticleDot(
      {required this.x,
      required this.y,
      required this.r,
      required this.opacity,
      required this.speed,
      required this.phase});
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Particle Painter
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingParticlePainter extends CustomPainter {
  final List<_ParticleDot> dots;
  final double progress;
  final Color color;

  _FloatingParticlePainter(
      {required this.dots, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dots) {
      final yPos =
          ((d.y - progress * d.speed + math.sin(progress * math.pi * 2 + d.phase) * 0.04) %
              1.0 +
              1.0) %
          1.0;
      final paint = Paint()
        ..color = color.withValues(alpha: d.opacity * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(
        Offset(d.x * size.width, yPos * size.height),
        d.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlePainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed Circle Painter
// ─────────────────────────────────────────────────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final int dashCount;

  _DashedCirclePainter({
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
    const gapFraction = 0.38;

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
  bool shouldRepaint(covariant _DashedCirclePainter old) => false;
}
