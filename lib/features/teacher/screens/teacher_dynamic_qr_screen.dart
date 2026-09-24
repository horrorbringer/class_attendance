import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/modern_app_bar.dart';
import '../../attendance/models/attendance_models.dart';
import '../repositories/teacher_repository.dart';
import 'teacher_live_feed_screen.dart';

class TeacherDynamicQrScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final String classRoomName;

  const TeacherDynamicQrScreen({
    super.key,
    required this.sessionId,
    required this.classRoomName,
  });

  @override
  ConsumerState<TeacherDynamicQrScreen> createState() => _TeacherDynamicQrScreenState();
}

class _TeacherDynamicQrScreenState extends ConsumerState<TeacherDynamicQrScreen> {
  DynamicQrData? _qrData;
  bool _isLoading = true;
  String? _errorMessage;
  int _secondsLeft = 20;
  bool _isDemoMode = false;
  bool _isNetworkPaused = false;
  bool _isPresentationMode = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _setupScreenPerformance();
    _fetchDynamicQr();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _qrData == null || _isLoading || _isNetworkPaused) return;
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        if (_isDemoMode) {
          _enableDemoMode();
        } else {
          _fetchDynamicQr();
        }
      }
    });
  }

  Future<void> _setupScreenPerformance() async {
    try {
      await WakelockPlus.enable();
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    try {
      WakelockPlus.disable();
      ScreenBrightness().resetApplicationScreenBrightness();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    super.dispose();
  }

  void _togglePresentationMode() {
    setState(() {
      _isPresentationMode = !_isPresentationMode;
    });
    if (_isPresentationMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _enableDemoMode() {
    final epochStep = DateTime.now().millisecondsSinceEpoch ~/ 20000;
    final mockToken = 'DEMO-ATTEND-${widget.sessionId}-$epochStep';
    if (mounted) {
      setState(() {
        _isDemoMode = true;
        _isLoading = false;
        _errorMessage = null;
        _qrData = DynamicQrData(
          sessionId: widget.sessionId,
          token: mockToken,
          intervalSeconds: 20,
          expiresInSeconds: 20,
          classRoom: widget.classRoomName,
          date: 'Today',
          startTime: 'Live',
        );
        _secondsLeft = 20;
      });
    }
  }

  Future<void> _fetchDynamicQr() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final data = await ref.read(teacherRepositoryProvider).getDynamicQr(widget.sessionId);

      if (mounted) {
        setState(() {
          _qrData = data;
          _secondsLeft = data.expiresInSeconds > 0 ? data.expiresInSeconds : data.intervalSeconds;
          _isLoading = false;
          _isNetworkPaused = false;
          _errorMessage = null;
          _isDemoMode = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        if (_qrData != null) {
          setState(() {
            _isNetworkPaused = true;
            _isLoading = false;
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isNetworkPaused) {
              _fetchDynamicQr();
            }
          });
        } else {
          final detail = e.response?.data is Map && (e.response!.data as Map).containsKey('detail')
              ? (e.response!.data['detail'].toString())
              : (e.message ?? 'Unable to connect to dynamic QR service');
          setState(() {
            _errorMessage = detail;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (_qrData != null) {
          setState(() {
            _isNetworkPaused = true;
            _isLoading = false;
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isNetworkPaused) {
              _fetchDynamicQr();
            }
          });
        } else {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  void _copyToken() {
    if (_qrData == null) return;
    Clipboard.setData(ClipboardData(text: _qrData!.token));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Token copied: ${_qrData!.token}'),
        backgroundColor: AppTheme.present,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _projectorUrl => ApiConstants.sessionLiveQr(widget.sessionId);

  Future<void> _launchProjectorUrl() async {
    final uri = Uri.parse(_projectorUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open browser: $e'),
            backgroundColor: AppTheme.absent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyProjectorUrl() {
    Clipboard.setData(ClipboardData(text: _projectorUrl));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Classroom Web Projector link copied to clipboard!'),
        backgroundColor: AppTheme.present,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToLiveMonitor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherLiveFeedScreen(
          sessionId: widget.sessionId,
          classRoomName: widget.classRoomName,
        ),
      ),
    );
  }

  void _showProjectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(ctx).padding.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              // Pull bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title and Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.connected_tv_rounded,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Classroom Web Projector',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Cast or open on podium PC, TV, or smart board',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // QR Code to scan directly from classroom laptop or tablet
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: _projectorUrl,
                      version: QrVersions.auto,
                      size: 140,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan with Classroom PC webcam or tablet to open instantly',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // URL Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _projectorUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primary),
                      onPressed: _copyProjectorUrl,
                      tooltip: 'Copy Link',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyProjectorUrl,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _launchProjectorUrl();
                      },
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                      label: const Text('Open Browser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Dual-Mode explanation card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withAlpha(30)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dual-Mode tip: Keep your phone on the Live Monitor to track arrivals while your classroom projector or PC displays the dynamic QR code for all students!',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.primary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPresentationMode) {
      return _buildPresentationView();
    }
    return _buildStandardView();
  }

  // ==========================================
  // IN-APP FULLSCREEN THEATER / PRESENTATION MODE
  // ==========================================
  Widget _buildPresentationView() {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final isCompactHeight = constraints.maxHeight < 680;
            final shortestSide = constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;
            final qrSize = isLandscape
                ? (constraints.maxHeight - 140).clamp(150.0, 320.0)
                : (isCompactHeight
                    ? (constraints.maxHeight * 0.36).clamp(170.0, 250.0)
                    : (shortestSide * 0.65).clamp(220.0, 360.0));

            Widget presentationContent;

            if (isLandscape) {
              presentationContent = Row(
                children: [
                  // Left control panel
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.present,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'LIVE ATTENDANCE • #${widget.sessionId}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.classRoomName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            IconButton.filled(
                              onPressed: _togglePresentationMode,
                              icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 20),
                              tooltip: 'Exit Presentation Mode',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        // Rotation countdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  value: _secondsLeft / (_qrData?.intervalSeconds ?? 20),
                                  strokeWidth: 2.5,
                                  color: _secondsLeft < 5 ? AppTheme.late : AppTheme.present,
                                  backgroundColor: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Rotates in $_secondsLeft s',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: _secondsLeft < 5 ? AppTheme.late : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Students: Scan with your app to check in',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _navigateToLiveMonitor,
                              icon: const Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.present),
                              label: Text(
                                'Open Live Monitor & Roster',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right QR code
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withAlpha(120),
                              blurRadius: 36,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: _qrData != null
                            ? QrImageView(
                                data: _qrData!.token,
                                version: QrVersions.auto,
                                size: qrSize,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF0F172A),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppTheme.primary),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Portrait Presentation
              presentationContent = SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 28,
                    maxWidth: 580,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.present,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'LIVE ATTENDANCE • SESSION #${widget.sessionId}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.classRoomName,
                                style: GoogleFonts.outfit(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          IconButton.filled(
                            onPressed: _togglePresentationMode,
                            icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 22),
                            tooltip: 'Exit Presentation Mode',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Center QR Showcase
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withAlpha(120),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: _qrData != null
                                ? QrImageView(
                                    data: _qrData!.token,
                                    version: QrVersions.auto,
                                    size: qrSize,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                  )
                                : SizedBox(
                                    width: qrSize,
                                    height: qrSize,
                                    child: const Center(
                                      child: CircularProgressIndicator(color: AppTheme.primary),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    value: _secondsLeft / (_qrData?.intervalSeconds ?? 20),
                                    strokeWidth: 2.5,
                                    color: _secondsLeft < 5 ? AppTheme.late : AppTheme.present,
                                    backgroundColor: const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Rotates in $_secondsLeft s',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _secondsLeft < 5 ? AppTheme.late : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Bottom Theater Helper
                      Column(
                        children: [
                          Text(
                            'Point student phone camera to scan and check in',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _navigateToLiveMonitor,
                            icon: const Icon(Icons.people_alt_rounded, size: 17, color: AppTheme.present),
                            label: Text(
                              'Switch to Live Monitor & Roster',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              backgroundColor: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: presentationContent,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // STANDARD DUAL-MODE VIEW
  // ==========================================
  Widget _buildStandardView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: ModernAppBar(
        title: '${widget.classRoomName} QR',
        subtitle: 'Dual-Mode Attendance',
        actions: [
          ModernAppBarAction(
            icon: Icons.connected_tv_rounded,
            tooltip: 'Web Projector Hub',
            onPressed: _showProjectorModal,
          ),
          const SizedBox(width: 6),
          ModernAppBarAction(
            icon: Icons.fullscreen_rounded,
            tooltip: 'Theater Presentation Mode',
            onPressed: _togglePresentationMode,
          ),
          const SizedBox(width: 6),
          ModernAppBarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Token Now',
            onPressed: () {
              if (_isDemoMode) {
                _enableDemoMode();
              } else {
                _fetchDynamicQr();
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _navigateToLiveMonitor,
                      icon: const Icon(Icons.people_alt_rounded, size: 20),
                      label: const Text('Open Live Monitor & Roster'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _showProjectorModal,
                    icon: const Icon(Icons.connected_tv_rounded),
                    tooltip: 'Web Projector Hub',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: AppTheme.primary.withAlpha(20),
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppTheme.primary.withAlpha(40)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 360 ? 14 : 24,
              vertical: 16,
            ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dual-mode projector banner
              InkWell(
                onTap: _showProjectorModal,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cast_connected_rounded, size: 20, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Classroom Projector Available',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Text(
                              'Tap to launch or copy link for PC/TV display',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title and Description
              Text(
                'Classroom Dynamic Attendance QR',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'This dynamic QR token rotates automatically every 20 seconds to prevent proxy check-ins.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              if (_isLoading && _qrData == null)
                const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                )
              else if (_errorMessage != null && _qrData == null)
                Container(
                  constraints: const BoxConstraints(minHeight: 200, maxWidth: 360),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.surfaceBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.absent.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.wifi_off_rounded, size: 36, color: AppTheme.absent),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to Load QR Token',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage ?? 'Network error occurred while fetching dynamic QR token.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _enableDemoMode,
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                            label: const Text('Use Demo QR'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _fetchDynamicQr,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else if (_qrData != null) ...[
                if (_isDemoMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withAlpha(50)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text(
                          'Demo Offline QR Mode • Auto-rotating',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // QR Display Card with Network Disconnect Guard
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(50),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: _isNetworkPaused ? 0.2 : 1.0,
                        child: QrImageView(
                          data: _qrData!.token,
                          version: QrVersions.auto,
                          size: (MediaQuery.of(context).size.width - 96).clamp(170.0, 240.0),
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0F172A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (_isNetworkPaused)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Reconnecting... QR Paused",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Countdown Timer Bar & Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: _secondsLeft / (_qrData?.intervalSeconds ?? 20),
                          strokeWidth: 3,
                          color: _secondsLeft < 5 ? AppTheme.late : AppTheme.primary,
                          backgroundColor: AppTheme.surfaceBorder,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Rotates in $_secondsLeft s',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _secondsLeft < 5 ? AppTheme.late : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Token text & Quick Copy Chip
                GestureDetector(
                  onTap: _copyToken,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key_rounded, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _qrData!.token,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }
}
