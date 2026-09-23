import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/models/attendance_models.dart';

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
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchDynamicQr();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _qrData == null || _isLoading) return;
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

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiConstants.sessionDynamicQr(widget.sessionId));
      final data = DynamicQrData.fromJson(response.data as Map<String, dynamic>);

      if (mounted) {
        setState(() {
          _qrData = data;
          _secondsLeft = data.expiresInSeconds > 0 ? data.expiresInSeconds : data.intervalSeconds;
          _isLoading = false;
          _errorMessage = null;
          _isDemoMode = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        final detail = e.response?.data is Map && (e.response!.data as Map).containsKey('detail')
            ? (e.response!.data['detail'].toString())
            : (e.message ?? 'Unable to connect to dynamic QR service');
        setState(() {
          _errorMessage = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.classRoomName} QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Token Now',
            onPressed: () {
              if (_isDemoMode) {
                _enableDemoMode();
              } else {
                _fetchDynamicQr();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Token',
            onPressed: _copyToken,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header description
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

              const SizedBox(height: 28),

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

                // QR Display Card
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
                  child: QrImageView(
                    data: _qrData!.token,
                    version: QrVersions.auto,
                    size: 240.0,
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
    );
  }
}
