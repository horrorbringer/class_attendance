import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import 'attendance_history_screen.dart';
import 'face_enrollment_screen.dart';
import 'notifications_screen.dart';
import 'qr_scanner_screen.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/widgets/modern_app_bar.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  bool _arabicLanguage = false;
  bool _absencePushAlerts = true;
  bool _biometricLogin = false;
  String _biometricSensorLabel = 'Biometrics';

  @override
  void initState() {
    super.initState();
    // Refresh student profile upon opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).fetchStudentProfile();
      _loadBiometricSettings();
    });
  }

  Future<void> _loadBiometricSettings() async {
    final enabled = await StorageService.isBiometricEnabled('student');
    final label = await BiometricService.getBiometricLabel();
    if (mounted) {
      setState(() {
        _biometricLogin = enabled;
        _biometricSensorLabel = label;
      });
    }
  }

  Future<void> _handleBiometricToggle(bool val) async {
    HapticFeedback.selectionClick();
    if (val) {
      final isAvailable = await BiometricService.isBiometricAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Biometric hardware (Fingerprint/Face ID) is not available or enrolled on this device.'),
                  ),
                ],
              ),
              backgroundColor: Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to enable $_biometricSensorLabel for your student account',
      );

      if (!authenticated) {
        if (mounted) {
          final err = BiometricService.lastErrorMessage ?? 'Biometric verification cancelled or failed.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFE11D48),
            ),
          );
        }
        return;
      }

      // Link credentials from last known or current student
      final lastCreds = await StorageService.getLastKnownCredentials('student');
      final authState = ref.read(authProvider);
      final studentUsername = authState.session?.username ?? authState.studentProfile?.studentId ?? '';

      if (lastCreds != null && lastCreds['username'] == studentUsername) {
        await StorageService.saveBiometricCredentials(
          username: lastCreds['username']!,
          password: lastCreds['password']!,
          role: 'student',
        );
      }

      await StorageService.setBiometricEnabled(true, 'student');
      if (mounted) {
        setState(() => _biometricLogin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('$_biometricSensorLabel login enabled successfully.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await StorageService.setBiometricEnabled(false, 'student');
      if (mounted) {
        setState(() => _biometricLogin = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_biometricSensorLabel login disabled.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF64748B),
          ),
        );
      }
    }
  }

  void _showDigitalIdModal(String fullName, String studentId, String section) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

            // Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_rounded, color: Color(0xFF10213E), size: 24),
                const SizedBox(width: 8),
                Text(
                  'Digital Student Identity',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10213E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Official University Attendance Card',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),

            // Physical Card Mockup
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10213E), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0610213E),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CAMPUS PASS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: const Color(0xFF1B2A4A),
                              child: Center(
                                child: Text(
                                  fullName.isNotEmpty ? fullName[0] : 'S',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              studentId,
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                            ),
                            Text(
                              section,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF93C5FD)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Integrated Barcode / QR Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        QrImageView(
                          data: studentId,
                          version: QrVersions.auto,
                          size: 110,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF10213E),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KIOSK SCAN READY',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF10213E),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Present to turnstile or\nkiosk camera for\ninstant access.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10213E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordModal() {
    HapticFeedback.lightImpact();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 18),
                  Text(
                    'Reset Password',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10213E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your current password and choose a secure new one.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: GoogleFonts.inter(color: const Color(0xFFB91C1C), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Current Password',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF10213E)),
                    decoration: InputDecoration(
                      hintText: 'Enter current password',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8)),
                        onPressed: () => setModalState(() => obscureOld = !obscureOld),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10213E), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'New Password',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF10213E)),
                    decoration: InputDecoration(
                      hintText: 'Minimum 8 characters',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8)),
                        onPressed: () => setModalState(() => obscureNew = !obscureNew),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10213E), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Confirm New Password',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF10213E)),
                    decoration: InputDecoration(
                      hintText: 'Re-enter new password',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8)),
                        onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10213E), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final oldP = oldPasswordController.text.trim();
                              final newP = newPasswordController.text.trim();
                              final confP = confirmPasswordController.text.trim();

                              if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
                                setModalState(() => errorMessage = 'Please fill out all password fields.');
                                return;
                              }
                              if (newP != confP) {
                                setModalState(() => errorMessage = 'New passwords do not match.');
                                return;
                              }
                              if (newP.length < 6) {
                                setModalState(() => errorMessage = 'New password must be at least 6 characters.');
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                errorMessage = null;
                              });

                              try {
                                await ref.read(authRepositoryProvider).changePassword(
                                  oldPassword: oldP,
                                  newPassword: newP,
                                  confirmPassword: confP,
                                );

                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text('Password updated successfully.'),
                                        ],
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  errorMessage = 'Failed to change password. Please check your current password.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10213E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Update Password',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
        ),
        content: Text(
          'Are you sure you want to log out of your Smart Attendance account?',
          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Log Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).studentProfile;

    // Data mapped directly from live profile or fallback to exact mockup 11 specs
    final fullName = profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Sarah Johnson';
    final studentId = profile?.studentId.isNotEmpty == true ? profile!.studentId : '#STU-2026-904';
    final section = profile?.classRoom?.name.isNotEmpty == true
        ? profile!.classRoom!.name
        : (profile?.classYear.isNotEmpty == true ? profile!.classYear : 'Computer Science — Section B');

    // Guardian information
    final rawGuardian = profile?.guardianContact ?? '';
    final guardianName = rawGuardian.isNotEmpty ? rawGuardian : 'Robert Johnson (Father)';
    const guardianDetails = '+1 (555) 019-2834 • r.johnson@workmail.com';

    final faceEmbeddingsCount = profile?.faceEmbeddingsCount ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModernAppBar(
        title: 'Profile & Settings',
        subtitle: 'Student Identity & Biometrics',
        actions: [
          ModernAppBarAction(
            icon: Icons.badge_outlined,
            tooltip: 'Digital Student Pass',
            onPressed: () => _showDigitalIdModal(fullName, studentId, section),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Avatar Circle with Navy Outer Ring (matching Mockup 11)
              Center(
                child: GestureDetector(
                  onTap: () => _showDigitalIdModal(fullName, studentId, section),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF10213E),
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) {
                              return Container(
                                color: const Color(0xFF10213E),
                                child: Center(
                                  child: Text(
                                    fullName.isNotEmpty ? fullName[0] : 'S',
                                    style: GoogleFonts.outfit(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10213E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.qr_code_rounded, size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 14),

              // Student Name
              Text(
                fullName,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10213E),
                  letterSpacing: -0.4,
                ),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.08, end: 0),

              const SizedBox(height: 4),

              // Student ID
              GestureDetector(
                onTap: () => _showDigitalIdModal(fullName, studentId, section),
                child: Text(
                  'Student ID: $studentId',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Department / Section
              Text(
                section,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB),
                ),
              ),

              const SizedBox(height: 24),

              // Emergency Guardian Card (matching Mockup 11)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x03000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMERGENCY GUARDIAN',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              guardianName,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guardianDetails,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone_outlined, color: Color(0xFF2563EB), size: 20),
                        tooltip: 'Call Guardian',
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: '+15550192834'));
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Guardian number copied: +1 (555) 019-2834'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF10213E),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.04, end: 0),

              const SizedBox(height: 16),

              // Settings Container (matching Mockup 11 with 4 row items)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x03000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Row 1: Arabic Language
                      _buildSettingsSwitchRow(
                        icon: Icons.public_rounded,
                        title: 'Arabic Language',
                        value: _arabicLanguage,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _arabicLanguage = val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val ? 'Arabic language enabled' : 'English language enabled'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 18, endIndent: 18),

                      // Row 2: Absence Push Alerts
                      _buildSettingsSwitchRow(
                        icon: Icons.notifications_none_rounded,
                        title: 'Absence Push Alerts',
                        value: _absencePushAlerts,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _absencePushAlerts = val);
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 18, endIndent: 18),

                      // Row 3: Biometric Login
                      _buildSettingsSwitchRow(
                        icon: Icons.fingerprint_rounded,
                        title: 'Biometric Login',
                        subtitle: _biometricLogin
                            ? '$_biometricSensorLabel enabled for fast sign-in'
                            : 'Enable $_biometricSensorLabel for fast sign-in',
                        value: _biometricLogin,
                        onChanged: _handleBiometricToggle,
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 18, endIndent: 18),

                      // Row 4: Reset Password (Tappable)
                      InkWell(
                        onTap: _showResetPasswordModal,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline_rounded, color: Color(0xFF10213E), size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Reset Password',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF10213E),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.04, end: 0),

              const SizedBox(height: 16),

              // Face Biometrics Status Quick Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faceEmbeddingsCount > 0 ? 'Face Biometrics Enrolled' : 'Face Biometrics Pending',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                faceEmbeddingsCount > 0 ? '$faceEmbeddingsCount/5 high-resolution templates synced' : 'Enroll face for kiosk & check-in',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF3B82F6), size: 20),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, end: 0),

              const SizedBox(height: 20),

              // Log Out Button (matching Mockup 11)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _confirmLogout,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Log Out',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.04, end: 0),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Persistent 5-Tab Bottom Navigation Bar with Profile Active (index 4)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 4, // Profile is active
          onTap: (index) {
            if (index == 0) {
              Navigator.popUntil(context, (route) => route.isFirst);
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            } else if (index == 4) {
              // Already on profile
            }
          },
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF10213E),
          unselectedItemColor: const Color(0xFF8C9BAE),
          selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Check-in',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSwitchRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF10213E), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10213E),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: const Color(0xFF10213E),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
