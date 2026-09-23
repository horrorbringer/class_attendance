import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/storage/secure_storage.dart';

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
  final bool isLoading;
  final bool isAuthenticated;
  final bool serverOffline;

  const SplashScreen({
    super.key,
    required this.onFinished,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.serverOffline = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isButtonPressed = false;
  bool _hasSeenOnboarding = true; // default true while checking
  bool _checkedStorage = false;
  bool _minTimerElapsed = false;
  bool _hasFinished = false;
  Timer? _splashTimer;

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
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
    final seen = await StorageService.hasSeenOnboarding();
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = seen;
        _checkedStorage = true;
      });
    }

    // Minimum display duration for the splash animation (1.6s)
    _splashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _minTimerElapsed = true);
        _evaluateAutoAdvance();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      _evaluateAutoAdvance();
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Automatically advance if user is already authenticated or has seen onboarding before
  void _evaluateAutoAdvance() {
    if (_hasFinished) return;
    if (!_minTimerElapsed || widget.isLoading) return;

    // If authenticated OR returning user who has seen onboarding: auto-advance
    if (widget.isAuthenticated || _hasSeenOnboarding) {
      _triggerFinish();
    }
  }

  void _triggerFinish() {
    if (_hasFinished) return;
    _hasFinished = true;
    widget.onFinished();
  }

  Future<void> _completeOnboarding() async {
    await StorageService.setOnboardingSeen(true);
    _triggerFinish();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether to display the Splash Screen or the First-Time Onboarding
    final showOnboarding = _checkedStorage &&
        !_hasSeenOnboarding &&
        !widget.isAuthenticated;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: showOnboarding
              ? _buildOnboardingFlow()
              : _buildPureSplashScreen(),
        ),
      ),
    );
  }

  /// Pure Animated Splash Screen (auto-advancing for authenticated or returning users)
  Widget _buildPureSplashScreen() {
    return GestureDetector(
      key: const ValueKey('PureSplashView'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Allow impatient users to tap to skip once loading completes
        if (!widget.isLoading) {
          _triggerFinish();
        }
      },
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // Pulsing Concentric Outer Ring + White Inner Circle Emblem
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF283F66).withValues(alpha: 0.35),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x15000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: CustomPaint(
                          painter: SchoolBuildingPainter(
                            color: Color(0xFF162846),
                            strokeWidth: 2.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.04, 1.04),
                    duration: 1600.ms,
                    curve: Curves.easeInOut,
                  ),
            ),

            const SizedBox(height: 44),

            // Title
            Text(
              'Smart Attendance',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 10),

            // Subtitle
            Text(
              'Effortless attendance, every day',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF8FA3BF),
                height: 1.4,
              ),
            ).animate().fadeIn(delay: 200.ms),

            const Spacer(flex: 3),

            // Subtle Status & Loading Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.isAuthenticated
                        ? 'Restoring secure session...'
                        : (widget.serverOffline
                            ? 'Offline mode • Tap to continue'
                            : 'Connecting to Beacon Network...'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Footer branding
            Text(
              'BEACON ACADEMY • v1.0',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: const Color(0xFF334155),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Onboarding Flow (Shown only for fresh installs before login)
  Widget _buildOnboardingFlow() {
    return SafeArea(
      key: const ValueKey('OnboardingView'),
      child: Column(
        children: [
          // Top Navigation Bar with "Skip"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF283F66).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Beacon Academy',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _completeOnboarding,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF283F66).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

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

          const SizedBox(height: 28),

          // Solid White Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == _slides.length - 1
                              ? 'Get Started'
                              : 'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentPage == _slides.length - 1
                              ? Icons.arrow_forward_rounded
                              : Icons.chevron_right_rounded,
                          size: 20,
                          color: const Color(0xFF10213E),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Quick Direct "Skip to Login" text button
          const SizedBox(height: 12),
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Already have an account? Sign In',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8FA3BF),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
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
