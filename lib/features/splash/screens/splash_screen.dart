import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingSlide {
  final Widget iconWidget;
  final String title;
  final String subtitle;

  const OnboardingSlide({
    required this.iconWidget,
    required this.title,
    required this.subtitle,
  });
}

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isButtonPressed = false;

  late final List<OnboardingSlide> _slides = [
    const OnboardingSlide(
      iconWidget: SizedBox(
        width: 44,
        height: 44,
        child: CustomPaint(
          painter: SchoolBuildingPainter(
            color: Color(0xFF162846),
            strokeWidth: 2.3,
          ),
        ),
      ),
      title: 'Smart Attendance',
      subtitle: 'Effortless attendance, every day',
    ),
    const OnboardingSlide(
      iconWidget: Icon(
        Icons.face_unlock_rounded,
        size: 42,
        color: Color(0xFF162846),
      ),
      title: 'Biometric Check-in',
      subtitle: 'Instant facial recognition powered by edge AI',
    ),
    const OnboardingSlide(
      iconWidget: Icon(
        Icons.qr_code_scanner_rounded,
        size: 42,
        color: Color(0xFF162846),
      ),
      title: 'Anti-Proxy Security',
      subtitle: 'Rotating session codes prevent proxy attendance',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF162846),
              Color(0xFF11213B),
              Color(0xFF0E1A2E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top breathable space matching Mockup 01
              const SizedBox(height: 24),

              // PageView content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 3),

                          // Concentric Outer Ring + White Inner Circle (Pixel-perfect match to Mockup 01)
                          Container(
                            width: 114,
                            height: 114,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF283F66).withValues(alpha: 0.38),
                            ),
                            child: Center(
                              child: Container(
                                width: 82,
                                height: 82,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x18000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: slide.iconWidget,
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .scale(duration: 400.ms, curve: Curves.easeOutBack),

                          const SizedBox(height: 52),

                          // Title matching Mockup 01 typography
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 12),

                          // Subtitle matching Mockup 01
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8FA3BF),
                              height: 1.4,
                            ),
                          ).animate().fadeIn(delay: 150.ms),

                          const Spacer(flex: 4),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Pagination Dots (Matching Mockup 01 between text and button)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final isActive = i == _currentPage;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 26 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF4A72E8)
                            : const Color(0xFF314668),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 38),

              // Solid White "Get Started" Button (Matching Mockup 01)
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 36),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _isButtonPressed = true),
                  onTapUp: (_) {
                    setState(() => _isButtonPressed = false);
                    _onNext();
                  },
                  onTapCancel: () => setState(() => _isButtonPressed = false),
                  child: AnimatedScale(
                    scale: _isButtonPressed ? 0.97 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Get Started',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom vector painter rendering the official university campus emblem
/// seen in `docs/ui/01 — Splash/Onboarding.png`.
class SchoolBuildingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const SchoolBuildingPainter({
    this.color = const Color(0xFF162846),
    this.strokeWidth = 2.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Building contour
    final path = Path();
    path.moveTo(w * 0.16, h * 0.82);
    path.lineTo(w * 0.16, h * 0.44);
    path.lineTo(w * 0.34, h * 0.44);
    path.lineTo(w * 0.50, h * 0.22);
    path.lineTo(w * 0.66, h * 0.44);
    path.lineTo(w * 0.84, h * 0.44);
    path.lineTo(w * 0.84, h * 0.82);
    path.lineTo(w * 0.16, h * 0.82);
    canvas.drawPath(path, paint);

    // Center circular clock/bell
    canvas.drawCircle(Offset(w * 0.50, h * 0.36), w * 0.05, paint);

    // Left wing window dots
    canvas.drawCircle(Offset(w * 0.28, h * 0.55), w * 0.028, fillPaint);

    // Right wing window dots
    canvas.drawCircle(Offset(w * 0.72, h * 0.55), w * 0.028, fillPaint);

    // Center arched door
    final doorPath = Path();
    doorPath.moveTo(w * 0.43, h * 0.82);
    doorPath.lineTo(w * 0.43, h * 0.67);
    doorPath.arcToPoint(
      Offset(w * 0.57, h * 0.67),
      radius: Radius.circular(w * 0.07),
      clockwise: true,
    );
    doorPath.lineTo(w * 0.57, h * 0.82);
    canvas.drawPath(doorPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
