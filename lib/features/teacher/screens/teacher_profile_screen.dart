import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import 'teacher_classes_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_reports_screen.dart';
import '../../../core/widgets/modern_app_bar.dart';

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  bool _biometricLogin = false;
  String _biometricSensorLabel = 'Biometrics';

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final enabled = await StorageService.isBiometricEnabled('teacher');
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
        reason: 'Authenticate to enable $_biometricSensorLabel for teacher portal',
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

      final lastCreds = await StorageService.getLastKnownCredentials('teacher');
      final authState = ref.read(authProvider);
      final teacherUsername = authState.session?.username ?? '';

      if (lastCreds != null && lastCreds['username'] == teacherUsername) {
        await StorageService.saveBiometricCredentials(
          username: lastCreds['username']!,
          password: lastCreds['password']!,
          role: 'teacher',
        );
      }

      await StorageService.setBiometricEnabled(true, 'teacher');
      if (mounted) {
        setState(() => _biometricLogin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('$_biometricSensorLabel login enabled for Instructor Portal.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await StorageService.setBiometricEnabled(false, 'teacher');
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

  // Assigned Registries matching docs/teacher/teacher-profile.png
  final List<Map<String, String>> _registries = [
    {
      'name': 'Grade 10-A Mathematics',
      'students': '25 Students',
    },
    {
      'name': 'Grade 11-B Physics Lab',
      'students': '28 Students',
    },
    {
      'name': 'Grade 9-C Algebra',
      'students': '22 Students',
    },
  ];

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherClassesScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherReportsScreen()),
      );
    }
    // index == 3 is already this profile screen
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE4F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Change Password',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your current password and a new secure password.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              if (errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    errorMsg!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: oldCtrl,
                obscureText: obscureOld,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureOld ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () => setSheetState(() => obscureOld = !obscureOld),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (oldCtrl.text.isEmpty ||
                            newCtrl.text.isEmpty ||
                            confirmCtrl.text.isEmpty) {
                          setSheetState(() => errorMsg = 'Please fill all fields');
                          return;
                        }
                        if (newCtrl.text != confirmCtrl.text) {
                          setSheetState(() => errorMsg = 'New passwords do not match');
                          return;
                        }
                        if (newCtrl.text.length < 8) {
                          setSheetState(
                            () => errorMsg = 'Password must be at least 8 characters',
                          );
                          return;
                        }

                        setSheetState(() {
                          isSubmitting = true;
                          errorMsg = null;
                        });

                        try {
                          await ref.read(authRepositoryProvider).changePassword(
                            oldPassword: oldCtrl.text,
                            newPassword: newCtrl.text,
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } on DioException catch (e) {
                          final msg = e.response?.data?['error'] ??
                              e.response?.data?['detail'] ??
                              'Failed to change password';
                          if (ctx.mounted) {
                            setSheetState(() {
                              isSubmitting = false;
                              errorMsg = msg.toString();
                            });
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setSheetState(() {
                              isSubmitting = false;
                              errorMsg = 'An unexpected error occurred';
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE4F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Notification Settings',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage alerts for class check-ins, tardiness, and session reports.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                title: Text(
                  'Live Attendance Alerts',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Notify when absent rates exceed 15%',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                value: true,
                activeTrackColor: const Color(0xFF2563EB),
                onChanged: (_) {},
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              SwitchListTile(
                title: Text(
                  'Session Summary Digests',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Receive end-of-day attendance reports',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                value: true,
                activeTrackColor: const Color(0xFF2563EB),
                onChanged: (_) {},
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE4F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Export Attendance CSV',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10213E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Download full semester attendance CSV for spreadsheet analysis.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Format: CSV (.csv)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        Text(
                          'Class ID, Student Name, Date, Status, Method',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: const Text('Download CSV Report'),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CSV report download initiated.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Log Out',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
        ),
        content: Text(
          'Are you sure you want to log out of your teacher account?',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final teacherName = authState.session?.teacher?.name ??
        authState.session?.displayName ??
        'David Henderson';
    final teacherEmail = authState.session?.teacher?.email ??
        (authState.session?.username != null
            ? '${authState.session!.username}@beaconacademy.edu'
            : 'd.henderson@beaconacademy.edu');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ModernAppBar(
        title: 'Instructor Profile',
        subtitle: 'Faculty Credentials & Security',
        actions: [
          ModernAppBarAction(
            icon: Icons.logout_rounded,
            tooltip: 'Log Out',
            iconColor: const Color(0xFFDC2626),
            onPressed: () => _showLogoutConfirmation(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher Info Row matching teacher-profile.png
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(
                            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacherName,
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF10213E),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Senior Math Department Head',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                teacherEmail,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Section: Assigned Registries
                    Text(
                      'Assigned Registries',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._registries.map((reg) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                reg['name']!,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10213E),
                                ),
                              ),
                              Text(
                                reg['students']!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Section: Account Settings
                    Text(
                      'Account Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Grouped Settings Card matching teacher-profile.png
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                          InkWell(
                            onTap: _showChangePasswordDialog,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Color(0xFF334155),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Change Password',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
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
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          // Biometric Authentication Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 21,
                                  color: Color(0xFF334155),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Biometric Authentication',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF10213E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _biometricLogin
                                            ? '$_biometricSensorLabel active for fast portal sign-in'
                                            : 'Enable $_biometricSensorLabel for instant portal login',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: _biometricLogin,
                                  activeTrackColor: const Color(0xFF10213E),
                                  onChanged: _handleBiometricToggle,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          InkWell(
                            onTap: _showNotificationSettingsDialog,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_none_rounded,
                                    size: 20,
                                    color: Color(0xFF334155),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Notification Settings',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
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
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          InkWell(
                            onTap: _showExportDialog,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.file_download_outlined,
                                    size: 20,
                                    color: Color(0xFF334155),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Export Attendance CSV',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
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

                    const SizedBox(height: 24),

                    // Log Out Button matching teacher-profile.png
                    InkWell(
                      onTap: _showLogoutConfirmation,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            'Log Out Account',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // 4-Tab Teacher Bottom Bar matching teacher-profile.png (Profile active at index 3)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 3, // Profile is active
          onTap: _onBottomNavTapped,
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
              icon: Icon(Icons.calendar_today_outlined),
              label: 'Classes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
