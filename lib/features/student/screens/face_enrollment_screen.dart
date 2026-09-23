import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/controllers/auth_controller.dart';

enum BiometricAngle {
  straight(
    stepNumber: 1,
    label: 'Frontal',
    yawText: '0° FRONT',
    targetMinYaw: -12.0,
    targetMaxYaw: 12.0,
    title: 'Look Directly at Camera',
    subtitle: 'Align your face in center. System will auto-capture when aligned.',
  ),
  left(
    stepNumber: 2,
    label: 'Left Profile',
    yawText: '-30° YAW',
    targetMinYaw: -50.0,
    targetMaxYaw: -18.0,
    title: 'Rotate Head Left ~30°',
    subtitle: 'Turn head slowly to the left until the angle locks green.',
  ),
  right(
    stepNumber: 3,
    label: 'Right Profile',
    yawText: '+30° YAW',
    targetMinYaw: 18.0,
    targetMaxYaw: 50.0,
    title: 'Rotate Head Right ~30°',
    subtitle: 'Turn head slowly to the right until the angle locks green.',
  );

  final int stepNumber;
  final String label;
  final String yawText;
  final double targetMinYaw;
  final double targetMaxYaw;
  final String title;
  final String subtitle;

  const BiometricAngle({
    required this.stepNumber,
    required this.label,
    required this.yawText,
    required this.targetMinYaw,
    required this.targetMaxYaw,
    required this.title,
    required this.subtitle,
  });
}

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  final String? studentId;
  final String? studentName;

  const FaceEnrollmentScreen({
    super.key,
    this.studentId,
    this.studentName,
  });

  @override
  ConsumerState<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _scannerAnim;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = true;

  // Real-time on-device Google ML Kit Face Pose Detector
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _isFaceDetected = false;
  double _currentYaw = 0.0;
  double _angleHoldProgress = 0.0;
  Timer? _holdTimer;

  bool _autoCaptureEnabled = true;

  final Map<BiometricAngle, XFile?> _capturedFaces = {
    BiometricAngle.straight: null,
    BiometricAngle.left: null,
    BiometricAngle.right: null,
  };

  BiometricAngle _activeAngle = BiometricAngle.straight;
  bool _isUploading = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isCameraInitializing = true;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No optical camera sensors found on this device.');
      }

      // Prioritize front-facing selfie camera for biometric registration
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _isCameraInitializing = false;
      });

      // Start real-time ML Kit optical frame streaming
      _startImageStream();
    } catch (e) {
      debugPrint('Live camera initialization error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isCameraInitializing = false;
        });
      }
    }
  }

  void _startImageStream() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      controller.startImageStream((CameraImage image) {
        if (_isDetecting || _isCapturing || _capturedFaces[_activeAngle] != null) return;
        _processCameraFrame(image);
      });
    } catch (e) {
      debugPrint('Error starting image stream: $e');
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    _isDetecting = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isNotEmpty) {
        final face = faces.first;
        final rawYaw = face.headEulerAngleY ?? 0.0;

        // Front camera mirroring adjust
        final adjustedYaw = -rawYaw;

        setState(() {
          _isFaceDetected = true;
          _currentYaw = adjustedYaw;
        });

        if (_autoCaptureEnabled) {
          _evaluateAngleLock(adjustedYaw);
        }
      } else {
        if (_isFaceDetected) {
          setState(() {
            _isFaceDetected = false;
            _angleHoldProgress = 0.0;
          });
          _holdTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint('ML Kit face processing error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _evaluateAngleLock(double yaw) {
    final min = _activeAngle.targetMinYaw;
    final max = _activeAngle.targetMaxYaw;
    final isMatching = (yaw >= min && yaw <= max);

    if (isMatching) {
      if (_holdTimer == null || !_holdTimer!.isActive) {
        _holdTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          setState(() {
            _angleHoldProgress = math.min(1.0, _angleHoldProgress + 0.12);
          });

          if (_angleHoldProgress >= 1.0) {
            timer.cancel();
            _triggerAutoCapture();
          }
        });
      }
    } else {
      _holdTimer?.cancel();
      if (_angleHoldProgress > 0) {
        setState(() {
          _angleHoldProgress = 0.0;
        });
      }
    }
  }

  Future<void> _triggerAutoCapture() async {
    if (_isCapturing || _capturedFaces[_activeAngle] != null) return;
    _holdTimer?.cancel();
    await _onShutterPressed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _scannerAnim.dispose();
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  int get _completedCount => _capturedFaces.values.where((f) => f != null).length;

  Future<void> _onShutterPressed() async {
    if (_isCapturing) return;

    // 1. Try taking a photo directly from the live CameraController
    final controller = _cameraController;
    if (_isCameraInitialized &&
        controller != null &&
        controller.value.isInitialized &&
        !controller.value.isTakingPicture) {
      try {
        setState(() => _isCapturing = true);

        // Pause stream before taking picture
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }

        final xFile = await controller.takePicture();
        _saveCapturedPhoto(xFile);

        // Resume stream for next angle if needed
        if (mounted && _completedCount < 3) {
          _startImageStream();
        }
        return;
      } catch (e) {
        debugPrint('Direct camera snapshot error: $e');
        // Resume image stream if snapshot failed
        _startImageStream();
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    }

    // 2. Fallback to OS image picker if live controller is unavailable
    await _captureWithPicker(ImageSource.camera);
  }

  Future<void> _captureWithPicker(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 1400,
        maxHeight: 1400,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo != null) {
        _saveCapturedPhoto(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera optical sensor error: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _saveCapturedPhoto(XFile photo) {
    setState(() {
      _capturedFaces[_activeAngle] = photo;
      _angleHoldProgress = 0.0;

      // Auto-advance to next incomplete angle
      final angles = BiometricAngle.values;
      for (final a in angles) {
        if (_capturedFaces[a] == null) {
          _activeAngle = a;
          break;
        }
      }
    });
  }

  void _retakeAngle(BiometricAngle angle) {
    setState(() {
      _capturedFaces[angle] = null;
      _activeAngle = angle;
      _angleHoldProgress = 0.0;
    });

    _startImageStream();
  }

  Future<void> _submitEnrollment() async {
    final photos = _capturedFaces.values.whereType<XFile>().toList();
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture at least 1 biometric angle before vector enrollment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final dio = ref.read(dioProvider);
      final formData = FormData();

      // student_id: string (optional if logged in as student; required if teacher/admin is enrolling)
      final targetStudentId = widget.studentId ?? ref.read(authProvider).studentProfile?.studentId;
      if (targetStudentId != null && targetStudentId.isNotEmpty) {
        formData.fields.add(MapEntry('student_id', targetStudentId));
      }

      // images: file(s) [supports 1 to 5 image uploads]
      for (int i = 0; i < photos.length; i++) {
        final file = photos[i];
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              file.path,
              filename: 'face_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        );
      }

      final response = await dio.post(ApiConstants.faceEnroll, data: formData);
      final data = response.data is Map ? (response.data as Map) : <dynamic, dynamic>{};
      final msg = data['message'] ?? 'Biometric facial templates successfully generated.';
      final dynamic enrolledCount = data['enrolled_count'] ?? photos.length;
      final dynamic totalTemplates = data['total_templates'] ?? enrolledCount;
      final dynamic errors = data['errors'];

      if (widget.studentId == null) {
        await ref.read(authProvider.notifier).fetchStudentProfile();
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFF334155), width: 1),
            ),
            title: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 32),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Biometrics Enrolled',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hub_outlined, size: 16, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      Text(
                        'Templates: $enrolledCount registered • Total: $totalTemplates active',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (errors != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Notice: $errors',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF59E0B)),
                  ),
                ],
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, true);
                  },
                  child: Text(
                    'Confirm & Return',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      String err = 'Biometric vector encoding failed.';
      if (e.response?.data != null && e.response?.data is Map) {
        err = e.response?.data['error']?.toString() ??
            e.response?.data['detail']?.toString() ??
            err;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = _capturedFaces[_activeAngle];
    final isDone = currentPhoto != null;
    final isAngleMatched = _currentYaw >= _activeAngle.targetMinYaw &&
        _currentYaw <= _activeAngle.targetMaxYaw;

    return Scaffold(
      backgroundColor: const Color(0xFF0B111E), // Executive Obsidian Biometric Lab Background
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top HUD Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF26354D)),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),

                      // Hands-Free Auto-Capture Switcher Pill
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _autoCaptureEnabled = !_autoCaptureEnabled;
                            _angleHoldProgress = 0.0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _autoCaptureEnabled ? const Color(0xFF132238) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _autoCaptureEnabled ? const Color(0xFF10B981) : const Color(0xFF475569),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _autoCaptureEnabled ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _autoCaptureEnabled ? 'AI AUTO-CAPTURE: ACTIVE' : 'MANUAL SHUTTER',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _autoCaptureEnabled ? const Color(0xFF6EE7B7) : const Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Gallery picker fallback
                      GestureDetector(
                        onTap: () => _captureWithPicker(ImageSource.gallery),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF26354D)),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Header Titles & Live Telemetry
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Face Biometrics',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.studentName != null
                                ? 'Enrolling: ${widget.studentName} [ID: ${widget.studentId ?? ''}]'
                                : 'Autonomous head pose tracking',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),

                      // Live Euler Angle Telemetry Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAngleMatched && _isFaceDetected
                              ? const Color(0xFF064E3B)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAngleMatched && _isFaceDetected
                                ? const Color(0xFF10B981)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAngleMatched ? Icons.check_circle_rounded : Icons.explore_outlined,
                              size: 13,
                              color: isAngleMatched ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isFaceDetected
                                  ? 'YAW: ${_currentYaw >= 0 ? '+' : ''}${_currentYaw.toStringAsFixed(1)}°'
                                  : _activeAngle.yawText,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAngleMatched ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 3-Segment Linear Step Progress
                  Row(
                    children: BiometricAngle.values.map((angle) {
                      final isCaptured = _capturedFaces[angle] != null;
                      final isCurrent = angle == _activeAngle;

                      return Expanded(
                        child: Container(
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isCaptured
                                ? const Color(0xFF10B981)
                                : isCurrent
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // 2. High-Tech Biometric HUD Viewfinder with LIVE FRONT CAMERA & ANGLE LOCK
            Center(
              child: SizedBox(
                width: 270,
                height: 270,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Radial Ring & Radar Mesh
                    CustomPaint(
                      size: const Size(270, 270),
                      painter: _BiometricRadarPainter(
                        progress: _scannerAnim.value,
                        isDone: isDone,
                        isAngleLocked: isAngleMatched && _isFaceDetected,
                        holdProgress: _angleHoldProgress,
                        activeAngle: _activeAngle,
                      ),
                    ),

                    // Central Circular Viewport Container
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF070B14),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF10B981)
                              : isAngleMatched && _isFaceDetected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2563EB),
                          width: isAngleMatched && _isFaceDetected ? 3 : 2,
                        ),
                      ),
                      child: ClipOval(
                        child: currentPhoto != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Captured Photo Image
                                  Image.file(
                                    File(currentPhoto.path),
                                    fit: BoxFit.cover,
                                  ),
                                  // Vector Grid Overlay on captured image
                                  CustomPaint(
                                    painter: _BiometricLandmarksPainter(),
                                  ),
                                  // Status Badge
                                  Positioned(
                                    bottom: 14,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.4),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                            const SizedBox(width: 4),
                                            Text(
                                              'EMBEDDINGS EXTRACTED',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  // LIVE FRONT CAMERA FEED
                                  if (_isCameraInitialized &&
                                      _cameraController != null &&
                                      _cameraController!.value.isInitialized)
                                    FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _cameraController!.value.previewSize?.height ?? 220,
                                        height: _cameraController!.value.previewSize?.width ?? 220,
                                        child: CameraPreview(_cameraController!),
                                      ),
                                    )
                                  else if (_isCameraInitializing)
                                    Container(
                                      color: const Color(0xFF0F172A),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                    )
                                  else
                                    // High-Precision Geometric Face Wireframe Fallback
                                    Container(
                                      color: const Color(0xFF070B14),
                                      child: CustomPaint(
                                        size: const Size(220, 220),
                                        painter: _BiometricFaceWireframePainter(
                                          angle: _activeAngle,
                                          currentYaw: _currentYaw,
                                          isLocked: isAngleMatched,
                                          animValue: _scannerAnim.value,
                                        ),
                                      ),
                                    ),

                                  // Semi-transparent Biometric Facial Reticle HUD on top of live camera
                                  CustomPaint(
                                    size: const Size(220, 220),
                                    painter: _BiometricFaceWireframePainter(
                                      angle: _activeAngle,
                                      currentYaw: _currentYaw,
                                      isLocked: isAngleMatched,
                                      animValue: _scannerAnim.value,
                                    ),
                                  ),

                                  // Real-time Angle Auto-Lock HUD Notification
                                  if (isAngleMatched && _isFaceDetected)
                                    Positioned(
                                      top: 20,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              'HOLD STILL (${(_angleHoldProgress * 100).toInt()}%)',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Directional Guidance Hint Badge
                                  if (!isAngleMatched && _isFaceDetected)
                                    Positioned(
                                      bottom: 18,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _activeAngle == BiometricAngle.left
                                                  ? Icons.turn_left_rounded
                                                  : _activeAngle == BiometricAngle.right
                                                      ? Icons.turn_right_rounded
                                                      : Icons.filter_center_focus_rounded,
                                              size: 14,
                                              color: const Color(0xFF38BDF8),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _activeAngle == BiometricAngle.left
                                                  ? 'TURN HEAD LEFT'
                                                  : _activeAngle == BiometricAngle.right
                                                      ? 'TURN HEAD RIGHT'
                                                      : 'CENTER FACE',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF38BDF8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),

                    // Precision HUD Reticles
                    Positioned(top: 10, left: 10, child: _buildHUDTargetMarker()),
                    Positioned(top: 10, right: 10, child: _buildHUDTargetMarker()),
                    Positioned(bottom: 10, left: 10, child: _buildHUDTargetMarker()),
                    Positioned(bottom: 10, right: 10, child: _buildHUDTargetMarker()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Instruction Panel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey(_activeAngle),
                  children: [
                    Text(
                      _activeAngle.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isAngleMatched && _isFaceDetected
                            ? const Color(0xFF34D399)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _activeAngle.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF94A3B8),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 1),

            // 4. 3 Angle Selector Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: BiometricAngle.values.map((angle) {
                  final isSelected = angle == _activeAngle;
                  final photo = _capturedFaces[angle];
                  final hasPhoto = photo != null;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _activeAngle = angle;
                        _angleHoldProgress = 0.0;
                      }),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF131D2E)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasPhoto
                                ? const Color(0xFF10B981)
                                : isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF1E293B),
                            width: isSelected || hasPhoto ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Circular Preview Thumbnail or Technical Compass Icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF090D16),
                                border: Border.all(
                                  color: hasPhoto
                                      ? const Color(0xFF10B981)
                                      : isSelected
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF334155),
                                  width: 1,
                                ),
                              ),
                              child: ClipOval(
                                child: hasPhoto
                                    ? Image.file(
                                        File(photo.path),
                                        fit: BoxFit.cover,
                                        width: 44,
                                        height: 44,
                                      )
                                    : Center(
                                        child: _buildAngleMeshIcon(angle),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Angle Name
                            Text(
                              angle.label,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              ),
                            ),

                            const SizedBox(height: 3),

                            // Status Tag
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  hasPhoto ? 'CAPTURED' : angle.yawText,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: hasPhoto
                                        ? const Color(0xFF10B981)
                                        : isSelected
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFF475569),
                                  ),
                                ),
                                if (hasPhoto) ...[
                                  const SizedBox(width: 3),
                                  GestureDetector(
                                    onTap: () => _retakeAngle(angle),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // 5. Biometric Shutter & Upload Control
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Camera Shutter Button (Manual Override)
                      GestureDetector(
                        onTap: _isCapturing ? null : _onShutterPressed,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDone ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                                    .withValues(alpha: 0.35),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone ? const Color(0xFF10B981) : Colors.white,
                              ),
                              child: _isCapturing
                                  ? const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      isDone ? Icons.refresh_rounded : Icons.camera_alt_rounded,
                                      color: isDone ? Colors.white : const Color(0xFF0F172A),
                                      size: 26,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Submit Enrollment Action
                  if (_completedCount > 0) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isUploading ? null : _submitEnrollment,
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.hub_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Register $_completedCount Face Template${_completedCount == 1 ? '' : 's'}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngleMeshIcon(BiometricAngle angle) {
    switch (angle) {
      case BiometricAngle.straight:
        return const Icon(Icons.filter_center_focus_rounded, size: 20, color: Color(0xFF38BDF8));
      case BiometricAngle.left:
        return const Icon(Icons.turn_left_rounded, size: 20, color: Color(0xFF94A3B8));
      case BiometricAngle.right:
        return const Icon(Icons.turn_right_rounded, size: 20, color: Color(0xFF94A3B8));
    }
  }

  Widget _buildHUDTargetMarker() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 1.2),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// High-Tech Custom Painters (Facial Mesh, Radar Scanning, Coordinate Reticles)
// -----------------------------------------------------------------------------

class _BiometricRadarPainter extends CustomPainter {
  final double progress;
  final bool isDone;
  final bool isAngleLocked;
  final double holdProgress;
  final BiometricAngle activeAngle;

  _BiometricRadarPainter({
    required this.progress,
    required this.isDone,
    required this.isAngleLocked,
    required this.holdProgress,
    required this.activeAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer Tick Marks (60 perimeter notches)
    final tickPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    final activeTickPaint = Paint()
      ..color = isDone
          ? const Color(0xFF10B981)
          : isAngleLocked
              ? const Color(0xFF10B981)
              : const Color(0xFF38BDF8)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 60; i++) {
      final angle = (i * 6) * math.pi / 180;
      final isMajor = i % 5 == 0;
      final inner = radius - (isMajor ? 10 : 5);
      final outer = radius - 2;

      final p1 = Offset(center.dx + inner * math.cos(angle), center.dy + inner * math.sin(angle));
      final p2 = Offset(center.dx + outer * math.cos(angle), center.dy + outer * math.sin(angle));

      final sweep = progress * 60;
      final isNearScan = (i - sweep).abs() < 5;

      canvas.drawLine(p1, p2, isNearScan || isAngleLocked ? activeTickPaint : tickPaint);
    }

    // 2. Green Hold Progress Lock Ring
    if (isAngleLocked && holdProgress > 0) {
      final holdPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 12),
        -math.pi / 2,
        holdProgress * 2 * math.pi,
        false,
        holdPaint,
      );
    } else {
      // Subtle Scanning Arc
      final arcPaint = Paint()
        ..color = (isDone ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 14),
        progress * 2 * math.pi,
        math.pi / 3,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BiometricRadarPainter oldDelegate) => true;
}

class _BiometricFaceWireframePainter extends CustomPainter {
  final BiometricAngle angle;
  final double currentYaw;
  final bool isLocked;
  final double animValue;

  _BiometricFaceWireframePainter({
    required this.angle,
    required this.currentYaw,
    required this.isLocked,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final baseColor = isLocked ? const Color(0xFF10B981) : const Color(0xFF38BDF8);

    final linePaint = Paint()
      ..color = baseColor.withValues(alpha: isLocked ? 0.6 : 0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = baseColor.withValues(alpha: isLocked ? 0.95 : 0.8)
      ..style = PaintingStyle.fill;

    // Shift wireframe smoothly according to actual live yaw angle!
    final double dynamicXShift = (currentYaw / 40.0).clamp(-1.0, 1.0) * 22.0;
    final faceCenter = Offset(center.dx + dynamicXShift, center.dy);

    // 1. Oval Head Boundary
    canvas.drawOval(
      Rect.fromCenter(center: faceCenter, width: 110, height: 145),
      linePaint,
    );

    // 2. Eye Level Axis
    canvas.drawLine(
      Offset(faceCenter.dx - 45, faceCenter.dy - 15),
      Offset(faceCenter.dx + 45, faceCenter.dy - 15),
      linePaint,
    );

    // 3. Facial Symmetry Vertical Axis
    canvas.drawLine(
      Offset(faceCenter.dx, faceCenter.dy - 65),
      Offset(faceCenter.dx, faceCenter.dy + 65),
      linePaint,
    );

    // 4. Biometric Landmark Nodes (Eyes, Nose, Cheeks, Jaw)
    final nodes = [
      Offset(faceCenter.dx - 22, faceCenter.dy - 15), // Left eye
      Offset(faceCenter.dx + 22, faceCenter.dy - 15), // Right eye
      Offset(faceCenter.dx, faceCenter.dy + 8),        // Nose apex
      Offset(faceCenter.dx - 18, faceCenter.dy + 35), // Left mouth corner
      Offset(faceCenter.dx + 18, faceCenter.dy + 35), // Right mouth corner
      Offset(faceCenter.dx, faceCenter.dy + 45),       // Chin apex
      Offset(faceCenter.dx - 38, faceCenter.dy + 8),  // Left cheekbone
      Offset(faceCenter.dx + 38, faceCenter.dy + 8),  // Right cheekbone
    ];

    for (final node in nodes) {
      canvas.drawCircle(node, isLocked ? 3.0 : 2.2, dotPaint);
    }

    // 5. Animated Laser Scan Bar (when not locked)
    if (!isLocked) {
      final scanY = (center.dy - 70) + (animValue * 140);
      final scanPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
        ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(center.dx - 60, scanY),
        Offset(center.dx + 60, scanY),
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BiometricFaceWireframePainter oldDelegate) => true;
}

class _BiometricLandmarksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);

    final points = [
      Offset(center.dx - 28, center.dy - 20),
      Offset(center.dx + 28, center.dy - 20),
      Offset(center.dx, center.dy + 4),
      Offset(center.dx - 20, center.dy + 36),
      Offset(center.dx + 20, center.dy + 36),
      Offset(center.dx, center.dy + 48),
    ];

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 2.5, dotPaint);
      if (i < points.length - 1) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BiometricLandmarksPainter oldDelegate) => false;
}
