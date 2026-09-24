import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/teacher_repository.dart';
import '../../attendance/models/attendance_models.dart';
import '../../auth/controllers/auth_controller.dart';
import 'teacher_classes_screen.dart';
import 'teacher_create_session_sheet.dart';
import 'teacher_dynamic_qr_screen.dart';
import 'teacher_live_feed_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_reports_screen.dart';
import 'teacher_session_detail_screen.dart';

class TeacherHomeScreen extends ConsumerStatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  ConsumerState<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends ConsumerState<TeacherHomeScreen> {
  List<TeacherClassSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTodayClasses();
  }

  Future<void> _fetchTodayClasses() async {
    try {
      final sessions = await ref.read(teacherRepositoryProvider).getTodayClasses();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openCreateSession() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TeacherCreateSessionSheet(),
    ).then((_) => _fetchTodayClasses());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final teacherName = authState.session?.displayName ?? 'Dr. Emily Okonkwo';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchTodayClasses,
          color: const Color(0xFF1B2A4A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with Teacher Profile & Quick Action
                _buildHeader(teacherName),

                const SizedBox(height: 20),

                // 2. Active "Live Attendance" Session Hero Card
                _buildLiveSessionHeroCard(),

                const SizedBox(height: 24),

                // 3. KPI Metrics Grid (2x2)
                _buildKpiMetricsGrid(),

                const SizedBox(height: 24),

                // 4. Quick Actions Hub
                _buildQuickActionsHub(),

                const SizedBox(height: 24),

                // 5. Today's Class Schedule Preview
                _buildScheduleSection(),

                const SizedBox(height: 24),

                // 6. Recent Activity & Security Alerts
                _buildRecentActivitySection(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),

      // Bottom Navigation Bar with Home (index 0) active
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 0, // Home is active
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherClassesScreen()),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherReportsScreen()),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherProfileScreen()),
              );
            }
          },
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF10213E),
          unselectedItemColor: const Color(0xFF8C9BAE),
          selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home_rounded, color: Color(0xFF10213E), size: 20),
              ),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              label: 'Classes',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Reports',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
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
        backgroundColor: Colors.white,
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
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String teacherName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherProfileScreen()),
              );
            },
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF1B2A4A),
                      child: Text(
                        teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getTimeGreeting()} 👋',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        teacherName,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10213E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Senior Science Instructor • Grade 11',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert Notification Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x03000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none_rounded, color: Color(0xFF10213E), size: 20),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Profile & Logout Menu Button
            PopupMenuButton<String>(
              tooltip: 'Teacher Options',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeacherProfileScreen()),
                  );
                } else if (val == 'logout') {
                  _showLogoutConfirmation();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x03000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.more_vert_rounded, color: Color(0xFF10213E), size: 20),
              ),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF10213E)),
                      const SizedBox(width: 10),
                      Text('Profile & Settings', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Text('Log Out', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildLiveSessionHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF162846),
            Color(0xFF11213B),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE ATTENDANCE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Anti-Proxy Active',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Class Name & Time
          Text(
            'Advanced Mathematics',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Text(
                '09:00 AM - 10:30 AM',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                'Room 402',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Attendance Counter & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '28 / 32 Checked In',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '87.5% Present',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF60A5FA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.875,
              minHeight: 6,
              backgroundColor: Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sensors_rounded, size: 18),
                  label: const Text('Live Monitor'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherLiveFeedScreen(
                          sessionId: 1,
                          classRoomName: 'Advanced Mathematics',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF10213E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('Show QR'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherDynamicQrScreen(
                          sessionId: 1,
                          classRoomName: 'Advanced Mathematics',
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildKpiMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview & Stats',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF10213E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Attendance',
                value: '91.8%',
                badge: '+2.4%',
                badgeColor: const Color(0xFF047857),
                icon: Icons.pie_chart_rounded,
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Active Classes',
                value: '3 Today',
                badge: '1 Live',
                badgeColor: const Color(0xFF2563EB),
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Present Now',
                value: '88 / 95',
                badge: '92.6%',
                badgeColor: const Color(0xFF047857),
                icon: Icons.group_rounded,
                iconColor: const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Absence Alerts',
                value: '2 Flags',
                badge: 'Needs Review',
                badgeColor: const Color(0xFFB45309),
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF10213E),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF10213E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'New Session',
                icon: Icons.add_circle_outline_rounded,
                color: const Color(0xFF2563EB),
                onTap: _openCreateSession,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                title: 'All Classes',
                icon: Icons.school_outlined,
                color: const Color(0xFF0F172A),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeacherClassesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                title: 'Analytics',
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFF0D9488),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeacherReportsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                title: 'Settings',
                icon: Icons.manage_accounts_outlined,
                color: const Color(0xFF475569),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeacherProfileScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10213E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Schedule",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10213E),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherClassesScreen()),
                );
              },
              child: Text(
                'View All →',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B2A4A)),
            ),
          )
        else if (_sessions.isNotEmpty)
          ..._sessions.map((s) {
            final title = s.classRoomName.isNotEmpty
                ? s.classRoomName
                : (s.classRoom?.name ?? 'Class Session');
            final time = s.startTime.isNotEmpty
                ? '${s.startTime} - ${s.endTime}'
                : '09:00 AM - 10:30 AM';
            final room = 'Room 402 • Main Block';
            final rate = s.isEnded ? 'Session Ended' : 'Live Session';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildScheduleItem(
                title: title,
                time: time,
                room: room,
                rate: rate,
                isLive: !s.isEnded,
                sessionId: s.id,
              ),
            );
          })
        else ...[
          _buildScheduleItem(
            title: 'Advanced Mathematics',
            time: '09:00 AM - 10:30 AM',
            room: 'Room 402 • Main Block',
            rate: '87% Present',
            isLive: true,
            sessionId: 1,
          ),
          const SizedBox(height: 10),
          _buildScheduleItem(
            title: 'Physics Lab II',
            time: '11:00 AM - 12:30 PM',
            room: 'Room 402 • Main Block',
            rate: '92% Present',
            isLive: false,
            sessionId: 2,
          ),
          const SizedBox(height: 10),
          _buildScheduleItem(
            title: 'Intro to Computer Science',
            time: '02:00 PM - 03:30 PM',
            room: 'Room 402 • Main Block',
            rate: '94% Present',
            isLive: false,
            sessionId: 3,
          ),
        ],
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildScheduleItem({
    required String title,
    required String time,
    required String room,
    required String rate,
    required bool isLive,
    required int sessionId,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherSessionDetailScreen(
              sessionId: sessionId,
              className: title,
              scheduleTime: time,
              room: room,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLive
                    ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLive ? Icons.sensors_rounded : Icons.school_outlined,
                color: isLive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10213E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LIVE NOW',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 6),
                      Text('•', style: GoogleFonts.inter(color: const Color(0xFFCBD5E1))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          room,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security & Notices',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF10213E),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automated Absence Alerts Dispatched',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Notices delivered to 4 guardians via Telegram & Email for unexcused absence.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anti-Proxy Wi-Fi Verification Active',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All check-ins strictly verified on campus subnet 10.20.0.0/16.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }
}
