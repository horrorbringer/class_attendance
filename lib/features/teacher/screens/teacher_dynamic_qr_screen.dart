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
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchDynamicQr();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _fetchDynamicQr();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDynamicQr() async {
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
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? 'Failed to fetch dynamic QR token';
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
            onPressed: _fetchDynamicQr,
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
                  height: 280,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                )
              else if (_errorMessage != null && _qrData == null)
                SizedBox(
                  height: 280,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.absent),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchDynamicQr, child: const Text('Retry')),
                    ],
                  ),
                )
              else if (_qrData != null) ...[
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
                        Text(
                          _qrData!.token,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppTheme.textSecondary,
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
