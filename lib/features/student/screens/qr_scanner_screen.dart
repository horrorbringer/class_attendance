import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/network/api_error_handler.dart';
import '../repositories/student_repository.dart';
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

  CameraController? _faceCameraController;
  bool _isFaceCameraInitialized = false;
  bool _isFaceCameraInitializing = false;

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

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios_device';
      }
    } catch (e) {
      debugPrint('Device ID detection error: $e');
    }
    return 'generic_device';
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks ||
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _laserAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  Future<void> _initFaceCamera() async {
    if (_isFaceCameraInitialized && _faceCameraController != null) return;

    _safeSetState(() => _isFaceCameraInitializing = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera sensors available on device');

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // On Android/emulators, ImageFormatGroup.jpeg throws CameraException.
      // Use nv21 on Android and bgra8888 on iOS.
      // Try medium preset first (optimal for emulators & mobile devices), fallback to low.
      CameraController? controller;
      try {
        controller = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );
        await controller.initialize();
      } catch (presetErr) {
        debugPrint('Medium resolution init failed on emulator ($presetErr), falling back to low preset:');
        controller = CameraController(
          frontCamera,
          ResolutionPreset.low,
          enableAudio: false,
        );
        await controller.initialize();
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _safeSetState(() {
        _faceCameraController = controller;
        _isFaceCameraInitialized = true;
        _isFaceCameraInitializing = false;
      });
    } catch (e) {
      debugPrint('Face camera init error: $e');
      if (mounted) {
        _safeSetState(() {
          _isFaceCameraInitialized = false;
          _isFaceCameraInitializing = false;
        });
      }
    }
  }

  Future<void> _switchMode(CheckinMode mode) async {
    if (_mode == mode) return;

    _safeSetState(() {
      _mode = mode;
      _errorMessage = null;
      _errorType = null;
    });

    if (mode == CheckinMode.face) {
      try {
        await _scannerController.stop();
      } catch (e) {
        debugPrint('Scanner stop error: $e');
      }
      await _initFaceCamera();
    } else {
      if (_faceCameraController != null) {
        final cam = _faceCameraController;
        _faceCameraController = null;
        _isFaceCameraInitialized = false;
        await cam?.dispose();
      }
      try {
        await _scannerController.start();
      } catch (e) {
        debugPrint('Scanner start error: $e');
      }
    }
  }

  @override
  void dispose() {
    _faceCameraController?.dispose();
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

  Future<void> _handleCheckinToken(String rawToken) async {
    if (_isProcessing) return;

    String token = rawToken.trim();

    // 1. Check if token is JSON encoded
    if (token.startsWith('{') && token.endsWith('}')) {
      try {
        final decoded = jsonDecode(token);
        if (decoded is Map) {
          token = decoded['qr_token']?.toString() ??
              decoded['token']?.toString() ??
              token;
        }
      } catch (_) {}
    }

    // 2. Parse URL if encoded as a web link or contains query params
    if (token.startsWith('http://') || token.startsWith('https://')) {
      final uri = Uri.tryParse(token);
      if (uri != null) {
        token = uri.queryParameters['qr_token'] ??
            uri.queryParameters['token'] ??
            (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : token);
      }
    }

    _safeSetState(() {
      _isProcessing = true;
      _errorMessage = null;
      _errorType = null;
    });

    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      final deviceId = await _getDeviceId();
      final checkinRes = await studentRepo.checkinQr(token, deviceId: deviceId);

      if (mounted) {
        if (checkinRes.isAlreadyCheckedIn) {
          final status = (checkinRes.record?['status'] ?? 'present').toString().toUpperCase();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Already checked in as '$status'!"),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
        _safeSetState(() {
          _isProcessing = false;
          _isSuccess = true;
          _successRecord = checkinRes.record ?? {'message': checkinRes.message};
          _successMessage = checkinRes.message;
        });
      }
    } on DioException catch (e) {
      final code = ApiErrorHandler.getErrorCode(e);
      final err = ApiErrorHandler.getMessage(e);
      String errType = 'qr';

      if (code == 'DEVICE_REUSE_BLOCKED') {
        errType = 'device_reuse';
      } else if (code == 'FACE_IDENTITY_MISMATCH') {
        errType = 'face_mismatch';
      } else if (code == 'QR_EXPIRED') {
        errType = 'qr_expired';
      } else if (code == 'TEACHER_LOCKED') {
        errType = 'teacher_locked';
      } else if (code == 'IMPOSSIBLE_TRAVEL') {
        errType = 'impossible_travel';
      } else if (code == 'SESSION_EXPIRED' || code == 'SESSION_ENDED') {
        errType = 'session_expired';
      } else if (code == 'NOT_ENROLLED') {
        errType = 'not_enrolled';
      } else if (e.response?.statusCode == 403) {
        errType = 'wifi';
      }

      if (mounted) {
        _safeSetState(() {
          _isProcessing = false;
          _errorMessage = err;
          _errorType = errType;
        });
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
          _errorType = 'qr';
        });
      }
    }
  }

  Future<void> _handleFaceCheckin() async {
    if (_isProcessing) return;

    String? photoPath;

    // 1. Try taking snapshot directly from live front optical camera
    if (_isFaceCameraInitialized &&
        _faceCameraController != null &&
        _faceCameraController!.value.isInitialized &&
        !_faceCameraController!.value.isTakingPicture) {
      try {
        final xFile = await _faceCameraController!.takePicture();
        photoPath = xFile.path;
      } catch (e) {
        debugPrint('Direct face capture error: $e');
      }
    }

    // 2. Fallback to image picker if direct camera capture not available
    if (photoPath == null) {
      try {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 1080,
          maxHeight: 1080,
          preferredCameraDevice: CameraDevice.front,
        );
        if (photo != null) {
          photoPath = photo.path;
        }
      } catch (e) {
        debugPrint('Camera picker fallback to gallery: $e');
        try {
          final photo = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 90,
            maxWidth: 1080,
            maxHeight: 1080,
          );
          if (photo != null) {
            photoPath = photo.path;
          }
        } catch (galleryErr) {
          debugPrint('Gallery picker error: $galleryErr');
        }
      }

      if (photoPath == null) return;
    }

    _safeSetState(() {
      _isProcessing = true;
      _errorMessage = null;
      _errorType = null;
    });

    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      final deviceId = await _getDeviceId();
      final checkinRes = await studentRepo.checkinFace(photoPath, deviceId: deviceId);

      if (mounted) {
        if (checkinRes.isAlreadyCheckedIn) {
          final status = (checkinRes.record?['status'] ?? 'present').toString().toUpperCase();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Already checked in as '$status'!"),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
        _safeSetState(() {
          _isProcessing = false;
          _isSuccess = true;
          _successRecord = checkinRes.record ?? {'message': checkinRes.message};
          _successMessage = checkinRes.message;
        });
      }
    } on DioException catch (e) {
      final code = ApiErrorHandler.getErrorCode(e);
      final err = ApiErrorHandler.getMessage(e);
      String errType = 'face';

      if (code == 'DEVICE_REUSE_BLOCKED') {
        errType = 'device_reuse';
      } else if (code == 'FACE_IDENTITY_MISMATCH') {
        errType = 'face_mismatch';
      } else if (code == 'TEACHER_LOCKED') {
        errType = 'teacher_locked';
      } else if (code == 'IMPOSSIBLE_TRAVEL') {
        errType = 'impossible_travel';
      } else if (code == 'SESSION_EXPIRED' || code == 'SESSION_ENDED') {
        errType = 'session_expired';
      } else if (code == 'NOT_ENROLLED') {
        errType = 'not_enrolled';
      } else if (e.response?.statusCode == 403) {
        errType = 'wifi';
      }

      if (mounted) {
        _safeSetState(() {
          _isProcessing = false;
          _errorMessage = err;
          _errorType = errType;
        });
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() {
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
                        onTap: () => _switchMode(CheckinMode.qr),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _mode == CheckinMode.qr ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _mode == CheckinMode.qr
                                ? const [
                                    BoxShadow(
                                      color: Color(0x03000000),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
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
                        onTap: () => _switchMode(CheckinMode.face),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _mode == CheckinMode.face ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _mode == CheckinMode.face
                                ? const [
                                    BoxShadow(
                                      color: Color(0x03000000),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
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
              GestureDetector(
                onTap: _mode == CheckinMode.face ? _handleFaceCheckin : null,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF2563EB), width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
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
                        else if (_isFaceCameraInitialized &&
                            _faceCameraController != null &&
                            _faceCameraController!.value.isInitialized)
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _faceCameraController!.value.previewSize?.height ?? 260,
                              height: _faceCameraController!.value.previewSize?.width ?? 260,
                              child: CameraPreview(_faceCameraController!),
                            ),
                          )
                        else if (_isFaceCameraInitializing)
                          Container(
                            color: const Color(0xFF0F172A),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFF0F172A),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.face_retouching_natural_rounded, size: 72, color: Color(0xFF38BDF8)),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Position Face in Frame',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Biometric Head Guide Oval in Face mode
                        if (_mode == CheckinMode.face)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(110),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                width: 1.5,
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
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
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
            ),

            const SizedBox(height: 16),

              // Viewport Subtext
              Text(
                _mode == CheckinMode.qr
                    ? 'Align QR code within frame'
                    : 'Position your face within frame',
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
                    backgroundColor: const Color(0xFF10213E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : (_mode == CheckinMode.qr ? _showManualTokenDialog : _handleFaceCheckin),
                  child: Text(
                    _mode == CheckinMode.qr ? 'Scan to Check In' : 'Scan Face to Check In',
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
              ] else if (_errorType == 'device_reuse') ...[
                _buildSecurityErrorCard(
                  icon: Icons.phonelink_lock_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  title: 'Device Already Used',
                  subtitle: 'Buddy Punching Blocked (DEVICE_REUSE_BLOCKED)',
                  message: 'This phone was already used to check in another student for this session.',
                  actionLabel: 'Return to Dashboard',
                  onAction: () => Navigator.of(context).pop(),
                ),
              ] else if (_errorType == 'face_mismatch') ...[
                _buildSecurityErrorCard(
                  icon: Icons.face_retouching_off_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  title: 'Identity Mismatch',
                  subtitle: 'Biometric Mismatch (FACE_IDENTITY_MISMATCH)',
                  message: _errorMessage ?? 'The recognized face does not match your enrolled student identity.',
                  actionLabel: 'Retry Face Scan',
                  onAction: () {
                    setState(() {
                      _errorMessage = null;
                      _errorType = null;
                    });
                    _handleFaceCheckin();
                  },
                ),
              ] else if (_errorType == 'qr_expired') ...[
                _buildSecurityErrorCard(
                  icon: Icons.timer_off_rounded,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  title: 'QR Code Expired',
                  subtitle: 'Rotating Token Timeout (QR_EXPIRED)',
                  message: 'Please scan the active rotating QR code currently displayed on the teacher\'s screen. Screenshots and old codes are expired.',
                  actionLabel: 'Scan Live QR',
                  onAction: () {
                    setState(() {
                      _errorMessage = null;
                      _errorType = null;
                    });
                  },
                ),
              ] else if (_errorType == 'teacher_locked') ...[
                _buildSecurityErrorCard(
                  icon: Icons.lock_person_rounded,
                  iconBg: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Teacher Locked',
                  subtitle: 'Instructor Sovereignty (TEACHER_LOCKED)',
                  message: _errorMessage ?? 'This attendance record was manually marked by your instructor and cannot be overwritten by automatic scan.',
                  actionLabel: 'Return to Dashboard',
                  onAction: () => Navigator.of(context).pop(),
                ),
              ] else if (_errorType == 'impossible_travel') ...[
                _buildSecurityErrorCard(
                  icon: Icons.warning_amber_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  title: 'Impossible Travel',
                  subtitle: 'Bilocation Detected (IMPOSSIBLE_TRAVEL)',
                  message: _errorMessage ?? 'You checked in to another class less than 15 minutes ago. Bilocation attendance is prohibited.',
                  actionLabel: 'Acknowledge',
                  onAction: () => Navigator.of(context).pop(),
                ),
              ] else if (_errorType == 'session_expired') ...[
                _buildSecurityErrorCard(
                  icon: Icons.event_busy_rounded,
                  iconBg: const Color(0xFFF1F5F9),
                  iconColor: const Color(0xFF475569),
                  title: 'Class Session Closed',
                  subtitle: 'Session Ended (SESSION_EXPIRED)',
                  message: _errorMessage ?? 'This session has ended and is no longer accepting check-ins.',
                  actionLabel: 'Back to Classes',
                  onAction: () => Navigator.of(context).pop(),
                ),
              ] else if (_errorType == 'not_enrolled') ...[
                _buildSecurityErrorCard(
                  icon: Icons.person_off_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  title: 'Wrong Classroom',
                  subtitle: 'Not Enrolled (NOT_ENROLLED)',
                  message: _errorMessage ?? 'You are not enrolled in this course or classroom section.',
                  actionLabel: 'Back to Dashboard',
                  onAction: () => Navigator.of(context).pop(),
                ),
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
              onPressed: () => _switchMode(CheckinMode.face),
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
              onPressed: () => _switchMode(CheckinMode.qr),
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

  Widget _buildSecurityErrorCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
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
                backgroundColor: const Color(0xFF10213E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onAction,
              child: Text(
                actionLabel,
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
                  _errorMessage = null;
                  _errorType = null;
                });
              },
              child: Text(
                'Cancel & Scan Again',
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
