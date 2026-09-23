import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../attendance/models/attendance_models.dart';
import '../../auth/controllers/auth_controller.dart';
import 'attendance_history_screen.dart';
import 'face_enrollment_screen.dart';
import 'notifications_screen.dart';
import 'profile_settings_screen.dart';
import 'qr_scanner_screen.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  bool _isLoading = true;
  List<StudentScheduleSession> _todaySchedule = [];
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      await ref.read(authProvider.notifier).fetchStudentProfile();
      final schedResponse = await dio.get(ApiConstants.studentScheduleToday);
      final schedList = schedResponse.data as List<dynamic>;

      if (mounted) {
        setState(() {
          _todaySchedule = schedList
              .map((e) => StudentScheduleSession.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openQrScanner() async {
    final checkedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (checkedIn == true) {
      _loadDashboardData();
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      setState(() => _selectedTabIndex = 0);
    } else if (index == 1) {
      _openQrScanner();
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
      );
    }
  }

  void _showProfileDialog() {
    final profile = ref.read(authProvider).studentProfile;
    final session = ref.read(authProvider).session;

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
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFE5EEF8),
                  child: const Icon(Icons.person_rounded, size: 36, color: Color(0xFF1A3258)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName ?? session?.displayName ?? 'Student',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10213E),
                        ),
                      ),
                      Text(
                        'ID: ${profile?.studentId ?? session?.username ?? ""} • ${profile?.classYear ?? "Year 3"}',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF5C6E84)),
                      ),
                      Text(
                        profile?.classRoom?.name ?? 'Assigned Classroom',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.face_rounded, size: 20),
              label: Text('Manage Biometrics (${profile?.faceEmbeddingsCount ?? 0} Enrolled)'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                ).then((_) => _loadDashboardData());
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out'),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.studentProfile;
    final fullName = profile?.fullName ?? authState.session?.displayName ?? 'Student';
    final firstName = fullName.split(' ').first;

    final todayFormatted = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    // Stat counts matching docs/ui/04 — Home Dashboard.png
    final totalClasses = _todaySchedule.length;
    final presentCount = _todaySchedule.where((s) => s.isCheckedIn).length;
    final pendingCount = totalClasses - presentCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: const Color(0xFF1A3258),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header matching docs/ui/04 — Home Dashboard.png
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good day, $firstName',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10213E),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          todayFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF6B7C93),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _showProfileDialog,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5EEF8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10213E).withAlpha(15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.person_rounded, size: 26, color: Color(0xFF1A3258)),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 22),

                // Top 3 Stat Cards matching docs/ui/04 — Home Dashboard.png
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'TODAY',
                        value: '$totalClasses',
                        subtitle: 'Classes',
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'PRESENT',
                        value: '$presentCount',
                        subtitle: 'Checked-in',
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'PENDING',
                        value: '$pendingCount',
                        subtitle: 'Remaining',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),

                // Biometric Setup Banner if not yet enrolled
                if (profile?.faceEmbeddingsCount == 0)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEBF3FE), Color(0xFFF1F5FB)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD6E4F8)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.face_rounded, color: Color(0xFF3B82F6), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Face Enrollment',
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10213E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Setup face templates for quick check-in',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF5C6E84),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A3258),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                            ).then((_) => _loadDashboardData());
                          },
                          child: const Text('Setup', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 24),

                // "Today's Schedule" Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Schedule',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                        );
                      },
                      child: Text(
                        'View Calendar',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Color(0xFF1A3258)),
                    ),
                  )
                else if (_todaySchedule.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F1E38).withAlpha(10),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 44, color: Color(0xFF8C9BAE)),
                        const SizedBox(height: 12),
                        Text(
                          'No scheduled classes for today',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF5C6E84),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._todaySchedule.map((session) => _buildScheduleCard(session)),
              ],
            ),
          ),
        ),
      ),

      // Bottom Navigation Bar matching docs/ui/04 — Home Dashboard.png
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: const Color(0xFFE5EEF8), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: _onBottomNavTapped,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF1A3258),
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
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today_rounded),
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
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1E38).withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6B7C93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(StudentScheduleSession session) {
    final isCheckedIn = session.isCheckedIn;
    final status = session.myStatus?.toLowerCase();

    Color pillBg;
    Color pillText;
    String statusLabel;

    if (isCheckedIn) {
      if (status == 'present') {
        pillBg = const Color(0xFFD1FAE5);
        pillText = const Color(0xFF059669);
        statusLabel = 'Present';
      } else if (status == 'late') {
        pillBg = const Color(0xFFFEF3C7);
        pillText = const Color(0xFFD97706);
        statusLabel = 'Late';
      } else {
        pillBg = const Color(0xFFD1FAE5);
        pillText = const Color(0xFF059669);
        statusLabel = 'Present';
      }
    } else {
      pillBg = const Color(0xFFF1F5F9);
      pillText = const Color(0xFF64748B);
      statusLabel = 'Upcoming';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1E38).withAlpha(12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Status Pill matching docs/ui/04 — Home Dashboard.png
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  session.classRoom,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10213E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pillText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Time, Room, Professor metadata
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF6B7C93)),
              const SizedBox(width: 4),
              Text(
                '${session.startTime} - ${session.endTime}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7C93)),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF6B7C93)),
              const SizedBox(width: 4),
              Text(
                'Classroom',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7C93)),
              ),
            ],
          ),

          if (!isCheckedIn) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3258),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _openQrScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: Text(
                  'Scan QR Code to Check In',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
