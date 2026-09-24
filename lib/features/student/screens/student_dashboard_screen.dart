import '../../auth/models/auth_models.dart';
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
import '../../attendance/models/attendance_models.dart';
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
  List<EnrolledClassroom> _enrolledClassrooms = [];
  int _selectedTabIndex = 0;

  // Report stats from GET /api/reports/student/<id>/
  double _attendanceRate = 0;
  int _reportPresent = 0;
  // Live State
  int _reportLate = 0;
  int _reportAbsent = 0;
  int _totalSessions = 0;
  bool _hasReportData = false;
  bool _hasShownFacePrompt = false;

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

      // Fetch today's schedule & enrolled classrooms
      List<DashboardClassItem> fetchedClasses = [];
      List<EnrolledClassroom> fetchedClassrooms = [];
      try {
        final scheduleResult = await studentRepo.getTodayScheduleWithClassrooms();
        fetchedClassrooms = scheduleResult.classrooms;

        for (final s in scheduleResult.sessions) {
          String status = 'upcoming';
          if (s.isCancelled) {
            status = 'cancelled';
          } else if (s.myStatus != null && s.myStatus!.isNotEmpty) {
            final st = s.myStatus!.toLowerCase();
            if (st == 'late') {
              status = 'late';
            } else if (st == 'absent') {
              status = 'absent';
            } else if (st == 'present') {
              status = 'present';
            }
          } else if (s.isCheckedIn) {
            status = 'present';
          }

          // Lookup room & teacher from matching enrolled classroom if not on session
          String location = s.room;
          String professor = s.teacher;
          if (location.isEmpty || professor.isEmpty) {
            final match = fetchedClassrooms.cast<EnrolledClassroom?>().firstWhere(
              (c) => c != null && (c.name.toLowerCase() == s.classRoom.toLowerCase() || c.id == s.id),
              orElse: () => null,
            );
            if (match != null) {
              if (location.isEmpty) location = match.room;
              if (professor.isEmpty) professor = match.teacher;
            }
          }

          fetchedClasses.add(
            DashboardClassItem(
              courseName: s.classRoom.isNotEmpty ? s.classRoom : 'Lecture Session',
              status: status,
              time: (s.startTime.isNotEmpty && s.endTime.isNotEmpty)
                  ? '${s.startTime.length >= 5 ? s.startTime.substring(0, 5) : s.startTime} - ${s.endTime.length >= 5 ? s.endTime.substring(0, 5) : s.endTime}'
                  : (s.startTime.isNotEmpty ? s.startTime : 'Scheduled'),
              location: location.isNotEmpty ? location : 'Main Campus',
              professor: professor.isNotEmpty ? professor : 'Faculty Instructor',
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
          _classes = fetchedClasses;
          _enrolledClassrooms = fetchedClassrooms;
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
          _classes = [];
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
    if (index == 1) {
      _openQrScanner();
    } else {
      setState(() => _selectedTabIndex = index);
    }
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.studentProfile;
    final fullName = (profile != null && profile.fullName.isNotEmpty)
        ? profile.fullName
        : (authState.session != null && authState.session!.displayName.isNotEmpty
            ? authState.session!.displayName
            : (authState.session?.username ?? 'Student'));
    final firstName = fullName.split(' ').first;

    final todayFormatted = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    // Stat counts matching docs/ui/04 — Home Dashboard.png (5 classes, 3 present, 2 pending)
    final totalClasses = _classes.length;
    final presentCount = _classes.where((s) => s.status == 'present' || s.status == 'late').length;
    final pendingCount = _classes.where((s) => s.status == 'upcoming').length;

    return PopScope(
      canPop: _selectedTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedTabIndex != 0) {
          setState(() => _selectedTabIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: IndexedStack(
          index: _selectedTabIndex,
          children: [
            _buildHomeTab(profile, fullName, firstName, todayFormatted, totalClasses, presentCount, pendingCount),
            const SizedBox.shrink(),
            const AttendanceHistoryScreen(isEmbedded: true),
            const NotificationsScreen(isEmbedded: true),
            const ProfileSettingsScreen(isEmbedded: true),
          ],
        ),
        bottomNavigationBar: _buildUnifiedStudentBottomBar(),
      ),
    );
  }

  Widget _buildUnifiedStudentBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0610213E),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
              ),
              _buildBottomNavItem(
                index: 1,
                icon: Icons.qr_code_scanner_rounded,
                activeIcon: Icons.qr_code_scanner_rounded,
                label: 'Check-in',
                isHighlight: true,
              ),
              _buildBottomNavItem(
                index: 2,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: 'History',
              ),
              _buildBottomNavItem(
                index: 3,
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'Alerts',
              ),
              _buildBottomNavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    bool isHighlight = false,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onBottomNavTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighlight
                      ? const Color(0xFF10213E)
                      : isSelected
                          ? const Color(0xFFEFF6FF)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isHighlight
                      ? Colors.white
                      : isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF10213E) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    StudentProfile? profile,
    String fullName,
    String firstName,
    String todayFormatted,
    int totalClasses,
    int presentCount,
    int pendingCount,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(61),
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
                    color: const Color(0xFF10213E).withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
            bottom: false,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = 4);
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF10213E), width: 1.5),
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
                                      fontSize: 16,
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
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10213E),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'STUDENT',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              todayFormatted,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Notification bell action
                  ModernAppBarAction(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifications & Alerts',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = 3);
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'PRESENT',
                        value: _hasReportData ? '$_reportPresent' : '$presentCount',
                        subtitle: _hasReportData ? '${_attendanceRate.toStringAsFixed(0)}% Rate' : 'Checked-in',
                        headerColor: const Color(0xFF10B981),
                        valueColor: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.04, end: 0),

                // Biometric Setup Banner if face templates = 0
                if (profile?.faceEmbeddingsCount == 0)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF2563EB), size: 18),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Face Enrollment',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Set up face templates for kiosk check-in',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
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
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                            ).then((_) => _loadDashboardData());
                          },
                          child: const Text('Setup', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 120.ms),

                const SizedBox(height: 16),

                // "Today's Schedule" Section Header matching Mockup 04
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Today\'s Schedule',
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10213E),
                        letterSpacing: -0.2,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTabIndex = 2);
                      },
                      child: Text(
                        'View Calendar',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Color(0xFF10213E)),
                    ),
                  )
                else if (_classes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.event_available_rounded, size: 28, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Classes Scheduled Today',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are all caught up! Pull to refresh to check for updates.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._classes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _buildClassScheduleCard(item)
                          .animate()
                          .fadeIn(duration: 200.ms, delay: (100 + index * 30).ms)
                          .slideY(begin: 0.03, end: 0),
                    );
                  }),

                const SizedBox(height: 14),

                // Enrolled Courses / Classrooms Section
                _buildEnrolledClassroomsSection(),

                const SizedBox(height: 14),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x02000000),
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
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: headerColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledClassroomsSection() {
    if (_enrolledClassrooms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enrolled Courses',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10213E),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Text(
                '${_enrolledClassrooms.length} Enrolled',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _enrolledClassrooms.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cr = _enrolledClassrooms[index];
              return Container(
                width: 210,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x02000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cr.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10213E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (cr.room.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Text(
                                cr.room,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        if (cr.teacher.isNotEmpty)
                          Expanded(
                            child: Text(
                              cr.teacher,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 250.ms);
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
        pillBg = const Color(0xFFFEE2E2);
        pillTextColor = const Color(0xFFDC2626);
        statusLabel = 'Absent';
        break;
      case 'cancelled':
        pillBg = const Color(0xFFF1F5F9);
        pillTextColor = const Color(0xFF64748B);
        statusLabel = 'Cancelled';
        break;
      default:
        pillBg = const Color(0xFFEFF6FF);
        pillTextColor = const Color(0xFF2563EB);
        statusLabel = 'Upcoming';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x02000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onClassCardTapped(item),
          borderRadius: BorderRadius.circular(13),
          splashColor: const Color(0xFFF1F5F9),
          highlightColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10213E),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: pillTextColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Thin Divider
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                const SizedBox(height: 8),

                // Bottom Row: Time, Room, Professor (matching Mockup 04)
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13.5, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      item.time,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, size: 13.5, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text(
                      item.location,
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
                          fontSize: 12,
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
