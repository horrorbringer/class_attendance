import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../attendance/models/attendance_models.dart';
import '../../auth/controllers/auth_controller.dart';
import 'teacher_create_session_sheet.dart';
import 'teacher_dynamic_qr_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_reports_screen.dart';
import 'teacher_session_detail_screen.dart';

class TeacherClassesScreen extends ConsumerStatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  ConsumerState<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends ConsumerState<TeacherClassesScreen> {
  List<TeacherClassSession> _sessions = [];

  // Fallback demo classes matching docs/teacher/teacher-class-list.png
  final List<Map<String, dynamic>> _mockupClasses = [
    {
      'id': 1,
      'name': 'Advanced Mathematics',
      'rate': '87% Present',
      'rateVal': 0.87,
      'isAmber': true,
      'time': '09:00 AM - 10:30 AM',
      'students': '32 students',
      'absent': '13% Absent',
      'room': 'Room 402 — Main Block',
      'isLive': true,
    },
    {
      'id': 2,
      'name': 'Physics Lab II',
      'rate': '92% Present',
      'rateVal': 0.92,
      'isAmber': false,
      'time': '11:00 AM - 12:30 PM',
      'students': '28 students',
      'absent': '8% Absent',
      'room': 'Room 402 — Main Block',
      'isLive': false,
    },
    {
      'id': 3,
      'name': 'Intro to Computer Science',
      'rate': '94% Present',
      'rateVal': 0.94,
      'isAmber': false,
      'time': '02:00 PM - 03:30 PM',
      'students': '35 students',
      'absent': '6% Absent',
      'room': 'Room 402 — Main Block',
      'isLive': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchTodayClasses();
  }

  Future<void> _fetchTodayClasses() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiConstants.teacherTodayClasses);
      final list = response.data as List<dynamic>;

      if (mounted) {
        setState(() {
          _sessions = list
              .map((e) => TeacherClassSession.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  void _openCreateSessionSheet() {
    final List<ClassRoomOption> classOptions = [];
    final seen = <int>{};
    for (final s in _sessions) {
      final crId = s.classRoom?.id ?? s.id;
      if (!seen.contains(crId)) {
        seen.add(crId);
        classOptions.add(
          ClassRoomOption(
            id: crId,
            name: s.classRoomName.isNotEmpty ? s.classRoomName : 'Class #$crId',
            code: 'CR-$crId',
          ),
        );
      }
    }

    TeacherCreateSessionSheet.show(
      context,
      classes: classOptions.isNotEmpty ? classOptions : null,
      onCreated: () => _fetchTodayClasses(),
    );
  }

  void _showTeacherProfileDialog() {
    final authState = ref.read(authProvider);
    final teacherName = authState.session?.teacher?.name ??
        authState.session?.displayName ??
        'Dr. Emily Okonkwo';
    final teacherEmail = authState.session?.teacher?.email ?? 'emily.okonkwo@school.edu';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
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
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacherName,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        teacherEmail,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB)),
              title: Text('Create On-Demand Session', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                _openCreateSessionSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_rounded, color: Color(0xFF1B2A4A)),
              title: Text('Projector Dynamic QR Screen', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                if (_sessions.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherDynamicQrScreen(
                        sessionId: _sessions.first.id,
                        classRoomName: _sessions.first.classRoomName,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherDynamicQrScreen(
                        sessionId: 1,
                        classRoomName: 'Physics Lab II',
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF1B2A4A)),
              title: Text('Profile & Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
              onTap: () {
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
    final teacherName = authState.session?.teacher?.name ??
        authState.session?.displayName ??
        'Dr. Emily Okonkwo';
    final todayFormatted = DateFormat('MMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchTodayClasses,
          color: const Color(0xFF1B2A4A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row matching teacher-class-list.png
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(
                            'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacherName,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                            Text(
                              'Senior Science Instructor',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Right Info / Security Shield Button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x060F172A),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.shield_outlined, color: Color(0xFF10213E), size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Classroom network security & beacon telemetry active.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 250.ms),

                const SizedBox(height: 20),

                // Hero Stats Card matching teacher-class-list.png
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x180F172A),
                        blurRadius: 18,
                        offset: Offset(0, 6),
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
                              'Today\'s Average Attendance',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '91.8%',
                              style: GoogleFonts.outfit(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Goal: above 95% • 3 Active classes',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFF283F66),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_graph_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

                const SizedBox(height: 24),

                // "Today's Schedule" Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Today\'s Schedule',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_sessions.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_sessions.length}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          todayFormatted,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _openCreateSessionSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 2),
                                Text(
                                  'New',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // List of Classes (Dynamic or Fallback Mockup)
                if (_sessions.isNotEmpty)
                  ..._sessions.map((session) {
                    final timeStr = (session.startTime.length >= 5 && session.endTime.length >= 5)
                        ? '${session.startTime.substring(0, 5)} - ${session.endTime.substring(0, 5)}'
                        : '${session.startTime} - ${session.endTime}';
                    final item = {
                      'id': session.id,
                      'name': session.classRoomName.isNotEmpty ? session.classRoomName : 'Class #${session.id}',
                      'rate': session.isEnded ? 'Ended' : (session.isQrValid ? 'Live Session' : 'Scheduled'),
                      'rateVal': session.isQrValid ? 1.0 : (session.isEnded ? 0.0 : 0.88),
                      'isAmber': session.isEnded,
                      'time': timeStr,
                      'students': 'Classroom #${session.classRoom?.id ?? session.id}',
                      'absent': session.isEnded ? 'Session ended' : 'Dynamic QR Active',
                      'room': session.classRoomName.isNotEmpty ? session.classRoomName : 'Main Hall',
                      'isLive': !session.isEnded && session.isQrValid,
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildClassCard(item),
                    );
                  })
                else
                  ..._mockupClasses.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildClassCard(item),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSessionSheet,
        backgroundColor: const Color(0xFF1B2A4A),
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Create Session',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
      // 5-Tab Teacher Bottom Bar with Classes (Index 1) active
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 1, // Classes is active
          onTap: (index) {
            if (index == 0) {
              _fetchTodayClasses();
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherSessionDetailScreen(
                    className: 'Physics Lab II',
                    scheduleTime: '11:00 AM - 12:30 PM',
                  ),
                ),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherReportsScreen()),
              );
            } else if (index == 4) {
              _showTeacherProfileDialog();
            }
          },
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF10213E),
          unselectedItemColor: const Color(0xFF8C9BAE),
          selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.school_outlined, color: Color(0xFF10213E), size: 20),
              ),
              label: 'Classes',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Session',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
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

  Widget _buildClassCard(Map<String, dynamic> item) {
    final isAmber = item['isAmber'] as bool;
    final isLive = item['isLive'] as bool;
    final rateVal = (item['rateVal'] as num).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherSessionDetailScreen(
                sessionId: item['id'] as int,
                className: item['name'] as String,
                scheduleTime: item['time'] as String,
                room: item['room'] as String,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Present Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['name'] as String,
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
                      color: isAmber ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['rate'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAmber ? const Color(0xFFB45309) : const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Time Row
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    item['time'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rateVal,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B2A4A)),
                ),
              ),
              const SizedBox(height: 8),

              // Student count & Absent rate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['students'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    item['absent'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),

              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              // Room & Live Now link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        item['room'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (isLive)
                    Text(
                      'Live Now',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
