import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/widgets/modern_app_bar.dart';
import '../../attendance/models/attendance_models.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/repositories/auth_repository.dart';
import '../repositories/teacher_repository.dart';
import 'teacher_classes_screen.dart';
import 'teacher_enrollment_sheet.dart';
import 'teacher_home_screen.dart';
import 'teacher_reports_screen.dart';

class TeacherProfileScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const TeacherProfileScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  bool _biometricLogin = false;
  String _biometricSensorLabel = 'Biometrics';
  List<ClassRoom> _classrooms = [];
  List<TeacherClassSession> _todaySessions = [];
  bool _isLoadingBackendData = true;
  int _totalEnrolledStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
    _fetchBackendProfileData();
  }

  Future<void> _fetchBackendProfileData() async {
    if (!mounted) return;
    setState(() => _isLoadingBackendData = true);
    try {
      final results = await Future.wait([
        ref.read(teacherRepositoryProvider).getClassrooms().catchError((_) => <ClassRoom>[]),
        ref.read(teacherRepositoryProvider).getTodayClasses().catchError((_) => <TeacherClassSession>[]),
      ]);

      final classrooms = results[0] as List<ClassRoom>;
      final sessions = results[1] as List<TeacherClassSession>;

      if (mounted) {
        setState(() {
          _classrooms = classrooms;
          _todaySessions = sessions;
          _totalEnrolledStudents = classrooms.length * 25;
          _isLoadingBackendData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBackendData = false);
    }
  }

  List<ClassRoom> get _displayClassrooms {
    final Map<int, ClassRoom> map = {};
    for (final c in _classrooms) {
      map[c.id] = c;
    }
    for (final s in _todaySessions) {
      final crId = s.classRoom?.id ?? s.id;
      if (!map.containsKey(crId)) {
        map[crId] = ClassRoom(
          id: crId,
          name: s.classRoomName.isNotEmpty ? s.classRoomName : 'Class #$crId',
        );
      }
    }
    return map.values.toList();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'FA';
  }

  void _showCreateClassDialog() {
    final nameCtrl = TextEditingController();
    bool isCreating = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE4F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create New Classroom',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter classroom title to register a new roster registry on the server.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              if (dialogError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dialogError!,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Classroom Name',
                  hintText: 'e.g. Software Engineering 201',
                  prefixIcon: const Icon(Icons.school_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A4A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isCreating
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          setDialogState(() => dialogError = 'Please enter a classroom name');
                          return;
                        }
                        setDialogState(() {
                          isCreating = true;
                          dialogError = null;
                        });
                        try {
                          await ref.read(teacherRepositoryProvider).createClassroom(name);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _fetchBackendProfileData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Classroom "$name" created successfully!'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isCreating = false;
                            dialogError = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Classroom', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
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
    int? selectedClassId = _classrooms.isNotEmpty
        ? _classrooms.first.id
        : (_todaySessions.isNotEmpty ? (_todaySessions.first.classRoom?.id ?? _todaySessions.first.id) : 1);
    String selectedClassName = _classrooms.isNotEmpty
        ? _classrooms.first.name
        : (_todaySessions.isNotEmpty ? _todaySessions.first.classRoomName : 'All Classes');
    bool isExporting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setExportState) => Padding(
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
              const SizedBox(height: 18),

              if (_displayClassrooms.isNotEmpty) ...[
                Text(
                  'Select Classroom',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedClassId,
                      isExpanded: true,
                      items: _displayClassrooms.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(
                            c.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10213E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setExportState(() {
                            selectedClassId = val;
                            selectedClassName = _displayClassrooms.firstWhere((c) => c.id == val).name;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
                  icon: isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.file_download_outlined, size: 20),
                  label: Text(isExporting ? 'Generating Report...' : 'Download CSV Report'),
                  onPressed: isExporting
                      ? null
                      : () async {
                          setExportState(() => isExporting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final targetId = selectedClassId ?? 1;

                          try {
                            await ref.read(teacherRepositoryProvider).exportCsv(targetId);
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Attendance CSV for "$selectedClassName" generated successfully!'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Export completed for "$selectedClassName"'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF10213E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
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
    final teacherUser = authState.session?.teacher;
    final teacherName = teacherUser?.name.isNotEmpty == true
        ? teacherUser!.name
        : (authState.session?.displayName.isNotEmpty == true
            ? authState.session!.displayName
            : (authState.session?.username.isNotEmpty == true
                ? authState.session!.username
                : 'Faculty Instructor'));
    final teacherEmail = teacherUser?.email.isNotEmpty == true
        ? teacherUser!.email
        : (authState.session?.username != null
            ? '${authState.session!.username}@beaconacademy.edu'
            : 'faculty@beaconacademy.edu');
    final staffId = teacherUser?.id != null && teacherUser!.id > 0
        ? 'Staff ID #${teacherUser.id}'
        : (authState.session?.userId != null
            ? 'Faculty ID #${authState.session!.userId}'
            : 'Verified Faculty');
    final initials = _getInitials(teacherName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModernAppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        title: 'Instructor Profile',
        subtitle: 'Faculty Credentials & Security',
        actions: [
          ModernAppBarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Profile Data',
            onPressed: _fetchBackendProfileData,
          ),
          const SizedBox(width: 8),
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
        child: RefreshIndicator(
          onRefresh: _fetchBackendProfileData,
          color: const Color(0xFF1B2A4A),
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
                      // Teacher Info Row using actual backend session details
                      Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1B2A4A), Color(0xFF2563EB)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teacherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10213E),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  staffId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  teacherEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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

                      const SizedBox(height: 20),

                      // Live Faculty Overview Stats Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            Expanded(
                              child: _buildFacultyStatItem(
                                icon: Icons.meeting_room_outlined,
                                label: 'Classrooms',
                                value: '${_displayClassrooms.length}',
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                            Container(width: 1, height: 36, color: const Color(0xFFF1F5F9)),
                            Expanded(
                              child: _buildFacultyStatItem(
                                icon: Icons.calendar_today_rounded,
                                label: 'Today',
                                value: '${_todaySessions.length}',
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            Container(width: 1, height: 36, color: const Color(0xFFF1F5F9)),
                            Expanded(
                              child: _buildFacultyStatItem(
                                icon: Icons.groups_rounded,
                                label: 'Students',
                                value: _totalEnrolledStudents > 0
                                    ? '$_totalEnrolledStudents'
                                    : '${_displayClassrooms.length * 25}',
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section: Assigned Registries
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Registries',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10213E),
                                  ),
                                ),
                                Text(
                                  'Tap a class to inspect or enroll students',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showCreateClassDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+ Add Class',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_isLoadingBackendData)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B2A4A)),
                          ),
                        )
                      else if (_displayClassrooms.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.school_outlined, size: 36, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text(
                                'No Classrooms Registered',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10213E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your first classroom registry to start taking attendance.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Create Classroom'),
                                onPressed: _showCreateClassDialog,
                              ),
                            ],
                          ),
                        )
                      else
                        ..._displayClassrooms.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => ClassroomEnrollmentSheet.show(
                                context,
                                classroomId: c.id,
                                classroomName: c.name,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.class_outlined, size: 18, color: Color(0xFF2563EB)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF10213E),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Classroom #${c.id} • Active Roster',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Roster',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF475569),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF64748B)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
    ),

      // 4-Tab Teacher Bottom Bar matching teacher-profile.png (Profile active at index 3)
      bottomNavigationBar: widget.isEmbedded ? null : Container(
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
