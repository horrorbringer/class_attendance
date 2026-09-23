import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/controllers/auth_controller.dart';

enum BiometricAngle {
  straight('Front Face', 'Look straight at the camera', 'Keep your head upright and look into the camera'),
  left('Left Profile', 'Turn your head slightly left', 'Turn head ~30° to capture your left facial contour'),
  right('Right Profile', 'Turn your head slightly right', 'Turn head ~30° to capture your right facial contour');

  final String label;
  final String title;
  final String prompt;

  const BiometricAngle(this.label, this.title, this.prompt);
}

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _scannerAnim;

  final Map<BiometricAngle, XFile?> _capturedFaces = {
    BiometricAngle.straight: null,
    BiometricAngle.left: null,
    BiometricAngle.right: null,
  };

  BiometricAngle _activeAngle = BiometricAngle.straight;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _scannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerAnim.dispose();
    super.dispose();
  }

  int get _completedCount => _capturedFaces.values.where((f) => f != null).length;

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo != null) {
        setState(() {
          _capturedFaces[_activeAngle] = photo;

          // Auto-advance to the next incomplete angle
          final angles = BiometricAngle.values;
          for (final a in angles) {
            if (_capturedFaces[a] == null) {
              _activeAngle = a;
              break;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _submitEnrollment() async {
    final photos = _capturedFaces.values.whereType<XFile>().toList();
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture at least 1 facial profile.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final dio = ref.read(dioProvider);
      final formData = FormData();

      for (var file in photos) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(file.path, filename: file.name),
          ),
        );
      }

      final response = await dio.post(ApiConstants.faceEnroll, data: formData);
      final msg = response.data?['message'] ?? 'Face biometric templates enrolled!';
      await ref.read(authProvider.notifier).fetchStudentProfile();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF131D2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Biometrics Verified',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              msg.toString(),
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, true);
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      String err = 'Enrollment failed.';
      if (e.response?.data != null && e.response?.data is Map) {
        err = e.response?.data['error']?.toString() ??
            e.response?.data['detail']?.toString() ??
            err;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: const Color(0xFFEF4444)),
        );
        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = _capturedFaces[_activeAngle];
    final isDone = currentPhoto != null;

    return Scaffold(
      backgroundColor: const Color(0xFF09111D), // ABA FacePay midnight dark theme
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar (Minimalist ABA Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'Face Biometrics',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'AI Anti-Spoofing Protected',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _capturePhoto(ImageSource.gallery),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. 3-Step Biometric Pills (ABA Mobile Segmented Indicator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: BiometricAngle.values.map((angle) {
                  final isSelected = angle == _activeAngle;
                  final hasPhoto = _capturedFaces[angle] != null;

                  Color pillColor;
                  Color textColor;
                  Color borderColor;

                  if (hasPhoto) {
                    pillColor = const Color(0xFF10B981).withAlpha(40);
                    textColor = const Color(0xFF10B981);
                    borderColor = const Color(0xFF10B981);
                  } else if (isSelected) {
                    pillColor = const Color(0xFF0072BC).withAlpha(50); // ABA Cyan-Blue
                    textColor = const Color(0xFF38BDF8);
                    borderColor = const Color(0xFF38BDF8);
                  } else {
                    pillColor = Colors.white.withAlpha(12);
                    textColor = const Color(0xFF64748B);
                    borderColor = Colors.transparent;
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeAngle = angle),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: pillColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasPhoto)
                              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981))
                            else
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                size: 12,
                                color: textColor,
                              ),
                            const SizedBox(width: 5),
                            Text(
                              angle.label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const Spacer(),

            // 3. ABA FacePay Biometric Oval HUD Scanner
            Center(
              child: SizedBox(
                width: 260,
                height: 310,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Pulsing Ambient Halo
                    Container(
                      width: 260,
                      height: 310,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(140),
                        boxShadow: [
                          BoxShadow(
                            color: (isDone ? const Color(0xFF10B981) : const Color(0xFF0072BC))
                                .withAlpha(45),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    // Center Face Viewport
                    Container(
                      width: 240,
                      height: 290,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1A2A),
                        borderRadius: BorderRadius.circular(130),
                        border: Border.all(
                          color: isDone ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(130),
                        child: currentPhoto != null
                            ? Image.file(
                                File(currentPhoto.path),
                                fit: BoxFit.cover,
                                width: 240,
                                height: 290,
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Dark Camera Placeholder with face silhouette
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.face_retouching_natural_rounded,
                                        size: 78,
                                        color: Colors.white.withAlpha(60),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Position Face Here',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withAlpha(150),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // ABA Style Animated Scanning Beam
                                  AnimatedBuilder(
                                    animation: _scannerAnim,
                                    builder: (context, child) {
                                      return Positioned(
                                        top: 30 + (_scannerAnim.value * 230),
                                        left: 20,
                                        right: 20,
                                        child: Container(
                                          height: 2.5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF38BDF8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF38BDF8).withAlpha(220),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // ABA Biometric 4 Corner Brackets
                    Positioned(
                      top: 4,
                      left: 14,
                      child: _buildCornerBracket(true, true, isDone),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: _buildCornerBracket(true, false, isDone),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 14,
                      child: _buildCornerBracket(false, true, isDone),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 14,
                      child: _buildCornerBracket(false, false, isDone),
                    ),

                    // Success Checkmark Badge if captured
                    if (isDone)
                      Positioned(
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withAlpha(120),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Profile Captured',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(curve: Curves.easeOutBack, duration: 300.ms),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 4. Dynamic Instructions Prompt (ABA Style clean typography)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_activeAngle),
                  children: [
                    Text(
                      _activeAngle.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _activeAngle.prompt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF94A3B8),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. ABA FacePay Biometric Scanner Shutter Control
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Shutter button (Large double-ring glowing button)
                      GestureDetector(
                        onTap: () => _capturePhoto(ImageSource.camera),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDone ? const Color(0xFF10B981) : const Color(0xFF0072BC))
                                    .withAlpha(80),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone ? const Color(0xFF10B981) : Colors.white,
                              ),
                              child: Icon(
                                isDone ? Icons.refresh_rounded : Icons.camera_alt_rounded,
                                size: 28,
                                color: isDone ? Colors.white : const Color(0xFF09111D),
                              ),
                            ),
                          ),
                        ),
                      ).animate().scale(duration: 250.ms),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Submit / Save Templates Action Bar
                  if (_completedCount > 0)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981), // Emerald verified
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isUploading ? null : _submitEnrollment,
                        child: _isUploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shield_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Confirm & Save $_completedCount Face Profile${_completedCount == 1 ? '' : 's'}',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ).animate().fadeIn(duration: 250.ms)
                  else
                    Text(
                      'Tap camera button to capture your front profile',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBracket(bool isTop, bool isLeft, bool isDone) {
    const double size = 24.0;
    const double thickness = 3.5;
    final color = isDone ? const Color(0xFF10B981) : const Color(0xFF38BDF8);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          isTop: isTop,
          isLeft: isLeft,
          color: color,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color color;
  final double thickness;

  _CornerBracketPainter({
    required this.isTop,
    required this.isLeft,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
