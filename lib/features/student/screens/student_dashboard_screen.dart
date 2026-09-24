import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../repositories/student_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import 'absence_alert_detail_screen.dart';
import 'attendance_history_screen.dart';
import 'face_enrollment_screen.dart';
import 'notifications_screen.dart';
import 'profile_settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../../../core/widgets/modern_app_bar.dart';

class DashboardClassItem {
  final String courseName;
  final String status; // 'present', 'late', 'upcoming', 'absent'
  final String time;
  final String location;
  final String professor;
  final String? checkedInAt;
  final String? method;

  const DashboardClassItem({
    required this.courseName,
    required this.status,
    required this.time,
    required this.location,
    required this.professor,
    this.checkedInAt,
    this.method,
  });
}

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  bool _isLoading = true;
  List<DashboardClassItem> _classes = [];
  int _selectedTabIndex = 0;

  // Report stats from GET /api/reports/student/<id>/
  double _attendanceRate = 0;
  int _reportPresent = 0;
  int _reportLate = 0;
  int _reportAbsent = 0;
  int _totalSessions = 0;
  bool _hasReportData = false;
  bool _hasShownFacePrompt = false;

  // Default Mockup 04 Classes
  final List<DashboardClassItem> _defaultMockupClasses = const [
    DashboardClassItem(
      courseName: 'Mathematics 101',
      status: 'present',
      time: '09:00 AM',
      location: 'Room 204',
      professor: 'Prof. Alan Turing',
      checkedInAt: '08:56 AM',
      method: 'Face Recognition',
    ),
    DashboardClassItem(
      courseName: 'Physics Lab 202',
      status: 'late',
      time: '11:00 AM',
      location: 'Lab Block C',
      professor: 'Dr. Marie Curie',
      checkedInAt: '11:14 AM',
      method: 'QR Code',
    ),
    DashboardClassItem(
      courseName: 'Intro to Computer Sci',
      status: 'upcoming',
      time: '02:00 PM',
      location: 'Virtual Room 5',
      professor: 'Grace Hopper',
    ),
    DashboardClassItem(
      courseName: 'World History',
      status: 'absent',
      time: '04:00 PM',
      location: 'Hall B',
      professor: 'Prof. Herodotus',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      await ref.read(authProvider.notifier).fetchStudentProfile();

      // Fetch today's schedule
      List<DashboardClassItem> fetchedClasses = [];
      try {
        final sessions = await studentRepo.getTodaySchedule();
        for (final s in sessions) {
          String status = 'upcoming';
          if (s.isCancelled) {
            status = 'cancelled';
          } else if (s.isCheckedIn) {
            final st = s.myStatus?.toLowerCase() ?? '';
            status = st == 'late' ? 'late' : 'present';
          } else if (s.myStatus?.toLowerCase() == 'absent') {
            status = 'absent';
          }

          fetchedClasses.add(
            DashboardClassItem(
              courseName: s.classRoom.isNotEmpty ? s.classRoom : 'Lecture Session',
              status: status,
              time: s.startTime.isNotEmpty ? s.startTime : '09:00 AM',
              location: 'Room 204',
              professor: 'Faculty Instructor',
              checkedInAt: s.checkedInAt,
              method: s.myMethod,
            ),
          );
        }
      } catch (_) {}

      // Fetch student attendance report for overall statistics
      final profile = ref.read(authProvider).studentProfile;
      if (profile != null) {
        try {
          final report = await studentRepo.getStudentReport(profile.id);
          if (mounted) {
            setState(() {
              _attendanceRate = report.attendanceRate;
              _reportPresent = report.presentCount;
              _reportLate = report.lateCount;
              _reportAbsent = report.absentCount;
              _totalSessions = report.totalRecordedSessions;
              _hasReportData = true;
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _classes = fetchedClasses.isNotEmpty ? fetchedClasses : List.from(_defaultMockupClasses);
          _isLoading = false;
        });

        // Flow 0: Soft-prompt face enrollment if never enrolled
        final profileNow = ref.read(authProvider).studentProfile;
        if (!_hasShownFacePrompt &&
            profileNow != null &&
            profileNow.faceEmbeddingsCount == 0) {
          _hasShownFacePrompt = true;
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _showFaceEnrollmentPrompt();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _classes = List.from(_defaultMockupClasses);
          _isLoading = false;
        });
      }
    }
  }

  void _showFaceEnrollmentPrompt() {
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
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF2563EB), size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Set Up Biometric Check-in',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enroll your facial embeddings now for touchless, lightning-fast kiosk attendance verification in classrooms.',
              style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                  ).then((_) => _loadDashboardData());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10213E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Enroll My Face Now', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Maybe Later', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  void _openQrScanner() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _onBottomNavTapped(int index) {
    HapticFeedback.selectionClick();
    if (index == 0) {
      setState(() => _selectedTabIndex = 0);
    } else if (index == 1) {
      _openQrScanner();
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
      ).then((_) => setState(() => _selectedTabIndex = 0));
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ).then((_) => setState(() => _selectedTabIndex = 0));
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
      ).then((_) => setState(() => _selectedTabIndex = 0));
    }
  }

  void _showProfileDialog() {
    HapticFeedback.lightImpact();
    final profile = ref.read(authProvider).studentProfile;
    final fullName = profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Sarah Johnson';
    final studentId = profile?.studentId.isNotEmpty == true ? profile!.studentId : '#STU-2026-904';
    final section = profile?.classRoom?.name ?? 'Computer Science — Section B';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10213E), width: 2),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: const Color(0xFF10213E),
                        child: Center(
                          child: Text(
                            fullName[0],
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
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
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10213E),
                        ),
                      ),
                      Text(
                        'Student ID: $studentId',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        section,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF10213E)),
              label: Text('View Profile & Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF10213E))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
              label: Text('Open QR Scanner', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10213E),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openQrScanner();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onClassCardTapped(DashboardClassItem item) {
    HapticFeedback.lightImpact();

    if (item.status == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.courseName} was cancelled by your instructor. Attendance check-in is not required.'),
          backgroundColor: const Color(0xFF10213E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (item.status == 'absent') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AbsenceAlertDetailScreen(
            courseName: item.courseName,
            date: DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
            scheduleTime: item.time,
            location: item.location,
            professor: item.professor,
            failureReason: 'No biometric or QR log recorded',
            alertTime: 'Today, 9:30 AM',
            guardianAlertTime: '9:15 AM',
          ),
        ),
      );
    } else if (item.status == 'present' || item.status == 'late') {
      _showAttendanceReceiptModal(item);
    } else {
      _showUpcomingClassModal(item);
    }
  }

  void _showAttendanceReceiptModal(DashboardClassItem item) {
    final isLate = item.status == 'late';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isLate ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLate ? Icons.access_time_filled_rounded : Icons.check_circle_rounded,
                    color: isLate ? const Color(0xFFD97706) : const Color(0xFF059669),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.courseName,
                        style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        isLate ? 'Attendance Logged (Tardy)' : 'Attendance Verified (Present)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLate ? const Color(0xFFD97706) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Class Time', item.time),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Campus Location', item.location),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Instructor', item.professor),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Checked In At', item.checkedInAt ?? item.time),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Verification Method', item.method ?? 'Mobile QR Scan'),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
                child: Text('Dismiss', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpcomingClassModal(DashboardClassItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.schedule_rounded, color: Color(0xFF64748B), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.courseName,
                        style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        'Upcoming Class Session',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Scheduled Start', item.time),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Room / Venue', item.location),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Faculty Instructor', item.professor),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Check-in Window', 'Opens 15 mins prior to class'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openQrScanner();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10213E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
                label: Text('Open QR Scanner to Check In', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E))),
      ],
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.studentProfile;
    final fullName = profile?.fullName.isNotEmpty == true ? profile!.fullName : (authState.session?.displayName ?? 'Sarah Johnson');
    final firstName = fullName.split(' ').first;

    final todayFormatted = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    // Stat counts matching docs/ui/04 — Home Dashboard.png (5 classes, 3 present, 2 pending)
    final totalClasses = _classes.length;
    final presentCount = _classes.where((s) => s.status == 'present' || s.status == 'late').length;
    final pendingCount = _classes.where((s) => s.status == 'upcoming').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(69),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10213E).withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
            bottom: false,
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showProfileDialog,
                    child: Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF10213E), width: 1.8),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                color: const Color(0xFF10213E),
                                child: Center(
                                  child: Text(
                                    firstName.isNotEmpty ? firstName[0] : 'S',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                style: GoogleFonts.outfit(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF10213E),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'STUDENT',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
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
                              'Campus Sync Active',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick QR Scan Action Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openQrScanner,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10213E),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1410213E),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Scan',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Notification bell action
                  ModernAppBarAction(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifications & Alerts',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: const Color(0xFF10213E),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Greeting & Date Banner
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getTimeGreeting()}, $firstName 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10213E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 13.5, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          todayFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(duration: 250.ms),

                const SizedBox(height: 22),

                // Top 3 Stat Cards matching Mockup 04 (TODAY, PRESENT, PENDING)
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'TODAY',
                        value: _hasReportData ? '$_totalSessions' : '$totalClasses',
                        subtitle: _hasReportData ? 'Total Sessions' : 'Classes',
                        headerColor: const Color(0xFF64748B),
                        valueColor: const Color(0xFF10213E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'PRESENT',
                        value: _hasReportData ? '$_reportPresent' : '$presentCount',
                        subtitle: _hasReportData ? '${_attendanceRate.toStringAsFixed(0)}% Rate' : 'Checked-in',
                        headerColor: const Color(0xFF10B981),
                        valueColor: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'PENDING',
                        value: _hasReportData ? '$_reportAbsent' : '$pendingCount',
                        subtitle: _hasReportData ? '$_reportLate late' : 'Remaining',
                        headerColor: const Color(0xFFF59E0B),
                        valueColor: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, end: 0),

                // Biometric Setup Banner if face templates = 0
                if (profile?.faceEmbeddingsCount == 0)
                  Container(
                    margin: const EdgeInsets.only(top: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Face Enrollment',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Set up face templates for instant kiosk check-in',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10213E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                            ).then((_) => _loadDashboardData());
                          },
                          child: const Text('Setup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 24),

                // "Today's Schedule" Section Header matching Mockup 04
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Today\'s Schedule',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10213E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                        );
                      },
                      child: Text(
                        'View Calendar',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator(color: Color(0xFF10213E)),
                    ),
                  )
                else
                  ..._classes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildClassScheduleCard(item)
                          .animate()
                          .fadeIn(duration: 220.ms, delay: (150 + index * 40).ms)
                          .slideY(begin: 0.04, end: 0),
                    );
                  }),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),

      // Persistent 5-Tab Bottom Navigation Bar with Home Active (index 0)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
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
              activeIcon: Icon(Icons.home_rounded),
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
              activeIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color headerColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: headerColor,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassScheduleCard(DashboardClassItem item) {
    Color pillBg;
    Color pillTextColor;
    String statusLabel;

    switch (item.status.toLowerCase()) {
      case 'present':
        pillBg = const Color(0xFFD1FAE5);
        pillTextColor = const Color(0xFF059669);
        statusLabel = 'Present';
        break;
      case 'late':
        pillBg = const Color(0xFFFEF3C7);
        pillTextColor = const Color(0xFFD97706);
        statusLabel = 'Late';
        break;
      case 'absent':
        pillBg = const Color(0xFFFFE4E6);
        pillTextColor = const Color(0xFFE11D48);
        statusLabel = 'Absent';
        break;
      case 'cancelled':
        pillBg = const Color(0xFFFEE2E2);
        pillTextColor = const Color(0xFFDC2626);
        statusLabel = 'Cancelled';
        break;
      default:
        pillBg = const Color(0xFFF1F5F9);
        pillTextColor = const Color(0xFF64748B);
        statusLabel = 'Upcoming';
        break;
    }

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onClassCardTapped(item),
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0xFFF1F5F9),
          highlightColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Course Name + Status Pill (matching Mockup 04)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.courseName,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10213E),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: pillTextColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Thin Divider
                const Divider(height: 1, color: Color(0xFFF8FAFC)),

                const SizedBox(height: 14),

                // Bottom Row: Time, Room, Professor (matching Mockup 04)
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      item.time,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      item.location,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        item.professor,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
