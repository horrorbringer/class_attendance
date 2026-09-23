import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'teacher_student_profile_screen.dart';

class RosterStudentItem {
  final String id;
  final String name;
  final String studentId;
  String status; // 'present', 'late', 'absent'
  final String email;
  final String guardianName;
  final String guardianPhone;

  RosterStudentItem({
    required this.id,
    required this.name,
    required this.studentId,
    required this.status,
    this.email = 'student@school.edu',
    this.guardianName = 'Parent Guardian',
    this.guardianPhone = '(555) 019-2834',
  });
}

class TeacherSessionDetailScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final String className;
  final String scheduleTime;
  final String room;

  const TeacherSessionDetailScreen({
    super.key,
    this.sessionId = 1,
    this.className = 'Physics Lab II',
    this.scheduleTime = '11:00 AM - 12:30 PM',
    this.room = 'Room 402 — Main Block',
  });

  @override
  ConsumerState<TeacherSessionDetailScreen> createState() => _TeacherSessionDetailScreenState();
}

class _TeacherSessionDetailScreenState extends ConsumerState<TeacherSessionDetailScreen> {
  late List<RosterStudentItem> _students;

  @override
  void initState() {
    super.initState();
    _initDemoRoster();
    _fetchLiveRoster();
  }

  void _initDemoRoster() {
    _students = [
      RosterStudentItem(
        id: '1',
        name: 'Marcus Vance',
        studentId: '202611',
        status: 'present',
        email: 'marcus.vance@school.edu',
        guardianName: 'Robert Vance',
        guardianPhone: '(555) 019-2834',
      ),
      RosterStudentItem(
        id: '2',
        name: 'Liam Smith',
        studentId: '202614',
        status: 'late',
        email: 'liam.smith@school.edu',
        guardianName: 'Sarah Smith',
        guardianPhone: '(555) 021-9872',
      ),
      RosterStudentItem(
        id: '3',
        name: 'Sarah Jenkins',
        studentId: '202619',
        status: 'absent',
        email: 'sarah.jenkins@school.edu',
        guardianName: 'Thomas Jenkins',
        guardianPhone: '(555) 034-7112',
      ),
      RosterStudentItem(
        id: '4',
        name: 'Clarissa Hall',
        studentId: '202621',
        status: 'present',
        email: 'clarissa.hall@school.edu',
        guardianName: 'Jessica Hall',
        guardianPhone: '(555) 045-8833',
      ),
      RosterStudentItem(
        id: '5',
        name: 'David Zhao',
        studentId: '202625',
        status: 'present',
        email: 'david.zhao@school.edu',
        guardianName: 'Wei Zhao',
        guardianPhone: '(555) 067-1144',
      ),
    ];
  }

  Future<void> _fetchLiveRoster() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.sessionRoster(widget.sessionId));
      if (res.data is Map && res.data['students'] is List) {
        final rawList = res.data['students'] as List<dynamic>;
        if (rawList.isNotEmpty && mounted) {
          setState(() {
            _students = rawList.map((e) {
              final m = e as Map<String, dynamic>;
              return RosterStudentItem(
                id: m['id']?.toString() ?? UniqueKey().toString(),
                name: m['student_name'] ?? m['name'] ?? 'Student',
                studentId: m['student_id'] ?? '202600',
                status: (m['status'] ?? 'present').toString().toLowerCase(),
                email: '${(m['student_name'] ?? 'student').toString().toLowerCase().replaceAll(' ', '.')}@school.edu',
              );
            }).toList();
          });
        }
      }
    } catch (_) {}
  }

  int get _presentCount => _students.where((s) => s.status == 'present' || s.status == 'late').length;
  int get _absentCount => _students.where((s) => s.status == 'absent').length;
  int get _totalCount => _students.length;

  void _toggleStudentStatus(RosterStudentItem student, bool isChecked) {
    setState(() {
      student.status = isChecked ? 'present' : 'absent';
    });
  }

  void _endSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'End Session & Submit',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
        ),
        content: Text(
          'Are you sure you want to conclude attendance for ${widget.className}? Absence notifications will be automatically triggered.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5C6E84)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF5C6E84), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dio = ref.read(dioProvider);
                await dio.post(ApiConstants.sessionEnd(widget.sessionId));
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session finalized and attendance roster submitted successfully.'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF991B1B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('End Session', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Navy Banner matching docs/teacher/teacher-session-detail.png
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1B2A4A),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row with "< Classes" and "Beacon Live"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Classes',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF283F66),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF38BDF8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Beacon Live',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Session Title
                  Text(
                    widget.className,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    'Today\'s Session • ${widget.scheduleTime}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3-Column Metrics Row
                  Row(
                    children: [
                      _buildMetricColumn('STUDENTS', '$_totalCount Total', Colors.white),
                      Container(width: 1, height: 32, color: const Color(0xFF2E456E)),
                      _buildMetricColumn('ATTENDANCE', '$_presentCount Present', Colors.white),
                      Container(width: 1, height: 32, color: const Color(0xFF2E456E)),
                      _buildMetricColumn('ABSENT', '$_absentCount Unresolved', const Color(0xFFF87171)),
                    ],
                  ),
                ],
              ),
            ),

            // Live Roster Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live Roster ($_totalCount)',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10213E),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _fetchLiveRoster();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Roster updated in real-time.'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Text(
                      'Refresh',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Students List
            Expanded(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                itemCount: _students.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final student = _students[index];
                  final isChecked = student.status == 'present' || student.status == 'late';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeacherStudentProfileScreen(
                            studentName: student.name,
                            studentId: student.studentId,
                            email: student.email,
                            guardianName: student.guardianName,
                            guardianPhone: student.guardianPhone,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
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
                                  student.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10213E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${student.studentId}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Status Badge
                          _buildStatusBadge(student.status),
                          const SizedBox(width: 14),

                          // Toggle Switch
                          CupertinoSwitch(
                            value: isChecked,
                            activeTrackColor: const Color(0xFF1B2A4A),
                            onChanged: (val) => _toggleStudentStatus(student, val),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms, delay: (index * 40).ms);
                },
              ),
            ),

            // Bottom Crimson "End Session & Submit" Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _endSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF991B1B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'End Session & Submit',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

    );
  }

  Widget _buildMetricColumn(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'present':
        bg = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        label = 'Present';
        break;
      case 'late':
        bg = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        label = 'Late';
        break;
      case 'absent':
      default:
        bg = const Color(0xFFFFE4E6);
        textColor = const Color(0xFFBE123C);
        label = 'Absent';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
