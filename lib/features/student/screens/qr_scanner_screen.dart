import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/controllers/auth_controller.dart';

enum CheckinMode { qr, face }

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final ImagePicker _imagePicker = ImagePicker();
  late AnimationController _laserAnim;

  CheckinMode _mode = CheckinMode.qr;
  bool _isProcessing = false;

  // Verification Results
  bool _isSuccess = false;
  String? _errorMessage;
  String? _errorType; // 'qr' or 'face'
  Map<String, dynamic>? _successRecord;
  String _successMessage = 'Checked in successfully!';

  @override
  void initState() {
    super.initState();
    _laserAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _laserAnim.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _isSuccess || _mode != CheckinMode.qr) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? scannedValue = barcodes.first.rawValue;
    if (scannedValue == null || scannedValue.trim().isEmpty) return;

    _handleCheckinToken(scannedValue.trim());
  }

  Future<void> _handleCheckinToken(String token) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _errorType = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        ApiConstants.checkinQr,
        data: {'qr_token': token},
      );

      final data = response.data as Map<String, dynamic>;
      final record = data['record'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _successRecord = record;
          _successMessage = data['message'] ?? 'Checked in successfully!';
        });
      }
    } on DioException catch (e) {
      String err = 'Unable to read QR code. Please ensure your device is aligned properly and try again.';
      String errType = 'qr';

      if (e.response?.statusCode == 403) {
        errType = 'wifi';
        err = 'Attendance check-in is restricted to the authorized campus network. Please connect to the School Campus Wi-Fi to verify attendance.';
      } else if (e.response?.statusCode == 429) {
        err = 'Request was throttled due to rapid attempts. Please wait 10 seconds before trying again.';
      } else if (e.response?.data != null && e.response?.data is Map) {
        final errMap = e.response!.data as Map;
        err = errMap['error']?.toString() ?? errMap['detail']?.toString() ?? err;
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = err;
          _errorType = errType;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
          _errorType = 'qr';
        });
      }
    }
  }

  Future<void> _handleFaceCheckin() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo == null) return;

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _errorType = null;
      });

      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(photo.path, filename: photo.name),
      });

      final response = await dio.post(
        ApiConstants.checkinFace,
        data: formData,
      );

      final data = response.data as Map<String, dynamic>;
      final record = data['record'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _successRecord = record;
          _successMessage = data['message'] ?? 'Face verified & checked in!';
        });
      }
    } on DioException catch (e) {
      String err = 'We couldn\'t verify your identity with the facial scan. Try again in better lighting or use QR code check-in.';
      String errType = 'face';

      if (e.response?.statusCode == 403) {
        errType = 'wifi';
        err = 'Attendance check-in is restricted to the authorized campus network. Please connect to the School Campus Wi-Fi to verify attendance.';
      } else if (e.response?.statusCode == 429) {
        err = 'Request was throttled due to rapid attempts. Please wait 10 seconds before trying again.';
      } else if (e.response?.data != null && e.response?.data is Map) {
        final errMap = e.response!.data as Map;
        err = errMap['error']?.toString() ?? errMap['detail']?.toString() ?? err;
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = err;
          _errorType = errType;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
          _errorType = 'face';
        });
      }
    }
  }

  void _showManualTokenDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Enter Token Manually',
          style: GoogleFonts.outfit(color: const Color(0xFF10213E), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter dynamic projector token (useful on simulator):',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF5C6E84)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF10213E)),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF1F4F9),
                hintText: 'e.g. dyn_1_9788f0b1...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8C9BAE)),
                prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18, color: Color(0xFF8C9BAE)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF5C6E84))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3258),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                _handleCheckinToken(val);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _simulateDemoSuccess() {
    setState(() {
      _isProcessing = false;
      _isSuccess = true;
      _errorMessage = null;
      _errorType = null;
      _successRecord = {
        'class_room_name': 'Mathematics 101',
        'class_room': 'Room 204',
        'checked_in_at': DateTime.now().toIso8601String(),
        'method': _mode == CheckinMode.face ? 'face' : 'qr',
      };
      _successMessage = 'Checked in successfully!';
    });
  }

  @override
  Widget build(BuildContext context) {
    // If Success state -> Render docs/ui/06 — Check-in Success.png
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    // If Error state -> Render docs/ui/07 — Check-in Error States.png
    if (_errorMessage != null && !_isProcessing) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Bar with back button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2EAF4)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Color(0xFF10213E),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_rounded, color: Color(0xFF1A3258)),
                        tooltip: 'Enter Manually',
                        onPressed: _showManualTokenDialog,
                      ),
                      if (_mode == CheckinMode.qr) ...[
                        IconButton(
                          icon: const Icon(Icons.flash_on_rounded, color: Color(0xFF1A3258)),
                          tooltip: 'Flashlight',
                          onPressed: () => _scannerController.toggleTorch(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch_rounded, color: Color(0xFF1A3258)),
                          tooltip: 'Switch Camera',
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Segmented Control matching docs/ui/05 — Check-in (QR + Face).png
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _mode = CheckinMode.qr;
                            _errorMessage = null;
                            _errorType = null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _mode == CheckinMode.qr ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _mode == CheckinMode.qr
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10213E).withAlpha(12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'QR Code',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: _mode == CheckinMode.qr ? FontWeight.bold : FontWeight.w500,
                                color: _mode == CheckinMode.qr ? const Color(0xFF10213E) : const Color(0xFF6B7C93),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _mode = CheckinMode.face;
                            _errorMessage = null;
                            _errorType = null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _mode == CheckinMode.face ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _mode == CheckinMode.face
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10213E).withAlpha(12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'Face Scan',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: _mode == CheckinMode.face ? FontWeight.bold : FontWeight.w500,
                                color: _mode == CheckinMode.face ? const Color(0xFF10213E) : const Color(0xFF6B7C93),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Scanner Viewport Box matching docs/ui/05 — Check-in (QR + Face).png
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF3B82F6), width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withAlpha(35),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_mode == CheckinMode.qr)
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                        )
                      else
                        Container(
                          color: const Color(0xFF0F172A),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.face_rounded, size: 72, color: Color(0xFF38BDF8)),
                                const SizedBox(height: 10),
                                Text(
                                  'Ready for Biometric Face',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Animated Blue Laser Scanning Beam
                      AnimatedBuilder(
                        animation: _laserAnim,
                        builder: (context, child) {
                          return Positioned(
                            top: 20 + (_laserAnim.value * 210),
                            left: 14,
                            right: 14,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withAlpha(220),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
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

              const SizedBox(height: 16),

              // Viewport Subtext
              Text(
                _mode == CheckinMode.qr ? 'Align QR code within frame' : 'Position your face within the frame',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF5C6E84),
                ),
              ),

              const SizedBox(height: 24),

              // Primary Action Button matching docs/ui/05 — Check-in (QR + Face).png
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3258),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : (_mode == CheckinMode.qr ? _showManualTokenDialog : _handleFaceCheckin),
                  child: Text(
                    _mode == CheckinMode.qr ? 'Scan to Check In' : 'Take Photo & Check In',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Processing Status Card matching docs/ui/05 — Check-in (QR + Face).png
              if (_isProcessing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verifying attendance...',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Connecting to academic secure server and running facial biometric checks. Keep still.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF6B7C93),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms),
            ],
          ),
        ),
      ),
    );
  }

  // Error State Screen matching docs/ui/07 — Check-in Error States.png
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with back button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _errorMessage = null;
                    _errorType = null;
                  });
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2EAF4)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Color(0xFF10213E),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title matching docs/ui/07 — Check-in Error States.png
              Text(
                'Check-In Failed',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your identity or code could not be verified.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF5C6E84),
                ),
              ),

              const SizedBox(height: 28),

              // Specific Error Card
              if (_errorType == 'wifi') ...[
                _buildWifiErrorCard(),
              ] else if (_errorType == 'face') ...[
                _buildFaceErrorCard(),
              ] else ...[
                _buildQrErrorCard(),
              ],

              const Spacer(),

              // Quick action to preview check-in success (Demo Mode)
              Center(
                child: TextButton.icon(
                  onPressed: _simulateDemoSuccess,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF64748B)),
                  label: Text(
                    'Preview Success Flow (Demo)',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Scan Failed',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10213E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Code verification error',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ??
                'Unable to read QR code. Please ensure your device is aligned properly and try again.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _errorType = null;
                });
              },
              child: Text(
                'Retry QR Scan',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10213E),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                setState(() {
                  _mode = CheckinMode.face;
                  _errorMessage = null;
                  _errorType = null;
                });
              },
              child: Text(
                'Switch to Face Scan',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildFaceErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.no_photography_outlined,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Face Not Recognized',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10213E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Biometric mismatch',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ??
                'We couldn\'t verify your identity with the facial scan. Try again in better lighting or use QR code check-in.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3258),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _errorType = null;
                });
                _handleFaceCheckin();
              },
              child: Text(
                'Try Face Scan Again',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10213E),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                setState(() {
                  _mode = CheckinMode.qr;
                  _errorMessage = null;
                  _errorType = null;
                });
              },
              child: Text(
                'Switch to QR Code',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildWifiErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFED7AA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFEA580C),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Wi-Fi Required',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10213E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Restricted Network (403)',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ??
                'Attendance check-in is restricted to the authorized campus network. Please connect to the School Campus Wi-Fi to verify attendance.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3258),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _errorType = null;
                });
              },
              child: Text(
                'Retry Check-in',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.wifi_rounded, size: 16),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10213E),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please check your Wi-Fi network settings.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              label: Text(
                'Verify Campus Wi-Fi',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // Success Screen matching docs/ui/06 — Check-in Success.png
  Widget _buildSuccessScreen() {
    final studentName = ref.watch(authProvider).session?.displayName ??
        ref.watch(authProvider).studentProfile?.fullName ??
        'Sarah Johnson';

    final className = _successRecord?['class_room_name'] ?? 'Mathematics 101';
    final location = _successRecord?['class_room'] ?? _successRecord?['room'] ?? 'Room 204';
    final timestamp = DateFormat('h:mm a — MMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),

              // Center Success Elements matching docs/ui/06 — Check-in Success.png
              Column(
                children: [
                  // Dual Halo Emerald Check Circle
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withAlpha(40),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 24),

                  // Student Circular Avatar
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1B2A4A),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Student Full Name
                  Text(
                    studentName,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10213E),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // "Checked in successfully!"
                  Text(
                    _successMessage,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Elevated White Card with Class, Location, Timestamp
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x04000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Class',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7C93)),
                            ),
                            Text(
                              className,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Color(0xFFEEF3FA), height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Location',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7C93)),
                            ),
                            Text(
                              location,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Color(0xFFEEF3FA), height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Timestamp',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7C93)),
                            ),
                            Text(
                              timestamp,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                ],
              ),

              // Back to Home Button matching docs/ui/06 — Check-in Success.png
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3258),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
