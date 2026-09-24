import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../repositories/teacher_repository.dart';
import '../../attendance/models/attendance_models.dart';
import '../../auth/controllers/auth_controller.dart';
import 'teacher_create_session_sheet.dart';
import 'teacher_home_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_reports_screen.dart';
import 'teacher_session_detail_screen.dart';
import 'teacher_enrollment_sheet.dart';
import '../../../core/widgets/modern_app_bar.dart';

class TeacherClassesScreen extends ConsumerStatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  ConsumerState<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends ConsumerState<TeacherClassesScreen> {
  List<TeacherClassSession> _sessions = [];

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final teacherName = authState.session?.teacher?.name ??
        authState.session?.displayName ??
        authState.session?.username ??
        'Faculty Instructor';
    final todayFormatted = DateFormat('MMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: ModernAppBar(
        title: 'Class Sessions',
        subtitle: 'Schedule & Rosters • $teacherName',
        actions: [
          ModernAppBarAction(
            icon: Icons.group_add_outlined,
            tooltip: 'Enrollment Roster',
            iconColor: Colors.white,
            backgroundColor: const Color(0xFF1E293B),
            onPressed: () {
              if (_sessions.isNotEmpty) {
                final first = _sessions.first;
                ClassroomEnrollmentSheet.show(
                  context,
                  classroomId: first.classRoom?.id ?? first.id,
                  classroomName: first.classRoomName.isNotEmpty ? first.classRoomName : 'Class #${first.id}',
                );
              } else {
                ClassroomEnrollmentSheet.show(
                  context,
                  classroomId: 1,
                  classroomName: 'General Classroom',
                );
              }
            },
          ),
          const SizedBox(width: 8),
          ModernAppBarAction(
            icon: Icons.add_rounded,
            tooltip: 'Create New Session',
            iconColor: Colors.white,
            backgroundColor: const Color(0xFF10213E),
            onPressed: _openCreateSessionSheet,
          ),
          const SizedBox(width: 8),
          ModernAppBarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Classes',
            onPressed: _fetchTodayClasses,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _fetchTodayClasses,
          color: const Color(0xFF1B2A4A),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

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
                        color: Color(0x0D0F172A),
                        blurRadius: 4,
                        offset: Offset(0, 2),
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
                      'classroomId': session.classRoom?.id ?? session.id,
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_outlined, size: 28, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Class Sessions Today',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "+ Create Session" below to start or schedule a new class session.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      // 4-Tab Teacher Bottom Bar with Classes (Index 1) active
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 1, // Classes is active
          onTap: (index) {
            if (index == 0) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
                );
              }
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
                child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF10213E), size: 20),
              ),
              label: 'Classes',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
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
                color: Color(0x03000000),
                blurRadius: 2,
                offset: Offset(0, 1),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          ClassroomEnrollmentSheet.show(
                            context,
                            classroomId: (item['classroomId'] ?? item['id']) as int,
                            classroomName: item['name'] as String,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.group_outlined, size: 13, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                'Roster',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Live Now',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ],
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
