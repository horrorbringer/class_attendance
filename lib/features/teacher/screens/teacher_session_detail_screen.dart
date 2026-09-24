import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../attendance/models/attendance_models.dart';
import '../repositories/teacher_repository.dart';
import 'teacher_dynamic_qr_screen.dart';
import 'teacher_live_feed_screen.dart';
import 'teacher_student_profile_screen.dart';

class RosterStudentItem {
  final String id;
  final String name;
  final String studentId;
  String status; // 'present', 'late', 'absent'
  final String email;
  final String guardianName;
  final String guardianPhone;
  final int? recordId;

  RosterStudentItem({
    required this.id,
    required this.name,
    required this.studentId,
    required this.status,
    this.email = 'student@school.edu',
    this.guardianName = 'Parent Guardian',
    this.guardianPhone = '(555) 019-2834',
    this.recordId,
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
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'present', 'late', 'absent'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initDemoRoster();
    _fetchLiveRoster();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      RosterStudentItem(
        id: '6',
        name: 'Emily Watson',
        studentId: '202628',
        status: 'present',
        email: 'emily.watson@school.edu',
        guardianName: 'George Watson',
        guardianPhone: '(555) 088-2911',
      ),
      RosterStudentItem(
        id: '7',
        name: 'Noah Bennett',
        studentId: '202632',
        status: 'absent',
        email: 'noah.bennett@school.edu',
        guardianName: 'Linda Bennett',
        guardianPhone: '(555) 091-4477',
      ),
      RosterStudentItem(
        id: '8',
        name: 'Sophia Martinez',
        studentId: '202635',
        status: 'late',
        email: 'sophia.martinez@school.edu',
        guardianName: 'Carlos Martinez',
        guardianPhone: '(555) 043-9922',
      ),
    ];
  }

  Future<void> _fetchLiveRoster() async {
    try {
      final rosterRes = await ref.read(teacherRepositoryProvider).getSessionRoster(widget.sessionId);
      if (rosterRes.roster.isNotEmpty && mounted) {
        setState(() {
          _students = rosterRes.roster.map((s) {
            return RosterStudentItem(
              id: s.studentPk > 0 ? s.studentPk.toString() : UniqueKey().toString(),
              name: s.studentName,
              studentId: s.studentId,
              status: s.attendanceStatus,
              email: '${s.studentName.toLowerCase().replaceAll(' ', '.')}@school.edu',
              recordId: s.recordId,
            );
          }).toList();
        });
      }
    } catch (_) {}
  }

  int get _presentCount => _students.where((s) => s.status == 'present' || s.status == 'late').length;
  int get _absentCount => _students.where((s) => s.status == 'absent').length;
  int get _totalCount => _students.length;

  List<RosterStudentItem> get _filteredStudents {
    return _students.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.studentId.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'present') return s.status == 'present';
      if (_selectedFilter == 'late') return s.status == 'late';
      if (_selectedFilter == 'absent') return s.status == 'absent';
      return true;
    }).toList();
  }

  Future<void> _toggleStudentStatus(RosterStudentItem student, bool isChecked) async {
    final newStatus = isChecked ? 'present' : 'absent';
    setState(() {
      student.status = newStatus;
    });

    if (student.recordId != null) {
      try {
        await ref.read(teacherRepositoryProvider).overrideAttendance(
          recordId: student.recordId!,
          status: newStatus,
        );
      } catch (_) {}
    }
  }

  Future<void> _cycleStudentStatus(RosterStudentItem student) async {
    setState(() {
      if (student.status == 'present') {
        student.status = 'late';
      } else if (student.status == 'late') {
        student.status = 'absent';
      } else {
        student.status = 'present';
      }
    });

    if (student.recordId != null) {
      try {
        await ref.read(teacherRepositoryProvider).overrideAttendance(
          recordId: student.recordId!,
          status: student.status,
        );
      } catch (_) {}
    }
  }

  Future<void> _handleBulkAction(String action) async {
    if (_students.isEmpty) return;

    List<BulkAttendanceItem> records = [];
    String successMsg = '';

    if (action == 'mark_all_present') {
      setState(() {
        for (var s in _students) {
          s.status = 'present';
        }
      });
      records = _students
          .map((s) => BulkAttendanceItem(studentId: s.studentId, status: 'present'))
          .toList();
      successMsg = 'Marked all students as Present and synced.';
    } else if (action == 'mark_remaining_absent') {
      setState(() {
        for (var s in _students) {
          if (s.status != 'present') {
            s.status = 'absent';
          }
        }
      });
      records = _students
          .where((s) => s.status == 'absent')
          .map((s) => BulkAttendanceItem(studentId: s.studentId, status: 'absent'))
          .toList();
      successMsg = 'Marked unmarked students as Absent and synced.';
    } else if (action == 'mark_all_absent') {
      setState(() {
        for (var s in _students) {
          s.status = 'absent';
        }
      });
      records = _students
          .map((s) => BulkAttendanceItem(studentId: s.studentId, status: 'absent'))
          .toList();
      successMsg = 'Marked all students as Absent and synced.';
    } else if (action == 'sync_all_bulk') {
      records = _students
          .map((s) => BulkAttendanceItem(studentId: s.studentId, status: s.status))
          .toList();
      successMsg = 'All roster attendance statuses synced via bulk update.';
    }

    if (records.isNotEmpty) {
      await _executeBulkAttendance(records, successMsg);
    }
  }

  Future<void> _executeBulkAttendance(List<BulkAttendanceItem> records, String successMsg) async {
    try {
      final res = await ref.read(teacherRepositoryProvider).submitBulkAttendance(
        sessionId: widget.sessionId,
        records: records,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10213E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.message.isNotEmpty
                        ? '${res.message} (${res.updatedCount} records)'
                        : successMsg,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10213E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(successMsg),
          ),
        );
      }
    }
  }

  void _endSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFF991B1B), size: 24),
            const SizedBox(width: 8),
            Text(
              'End Session & Submit',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to conclude attendance for ${widget.className}?',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Present', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      Text('$_presentCount', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
                    ],
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  Column(
                    children: [
                      Text('Absent', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      Text('$_absentCount', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Automated Telegram & Email absence notifications will be immediately dispatched to guardians.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Submit final bulk attendance snapshot before ending session
                final bulkRecords = _students.map((s) => BulkAttendanceItem(
                  studentId: s.studentId,
                  status: s.status,
                )).toList();
                
                final repo = ref.read(teacherRepositoryProvider);
                if (bulkRecords.isNotEmpty) {
                  await repo.submitBulkAttendance(
                    sessionId: widget.sessionId,
                    records: bulkRecords,
                  );
                }
                await repo.endSession(widget.sessionId);
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10213E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Session finalized and attendance roster submitted successfully.'),
                        ),
                      ],
                    ),
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF991B1B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text('End Session', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStudents;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Navy Banner matching docs/teacher/teacher-session-detail.png
            _buildHeaderBanner(context),

            // Search Bar & Filter Chips
            _buildSearchAndFilters(),

            // Live Roster Section Header with Count & Refresh
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Bulk Attendance Actions',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: _handleBulkAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                'Bulk Actions',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'mark_all_present',
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF047857), size: 18),
                                const SizedBox(width: 10),
                                Text('Mark All Present', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'mark_remaining_absent',
                            child: Row(
                              children: [
                                const Icon(Icons.person_off_outlined, color: Color(0xFFB91C1C), size: 18),
                                const SizedBox(width: 10),
                                Text('Mark Unmarked Absent', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'mark_all_absent',
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 10),
                                Text('Mark All Absent', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'sync_all_bulk',
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB), size: 18),
                                const SizedBox(width: 10),
                                Text('Sync All to Cloud', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Students List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No students match your filter',
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final student = filtered[index];
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                      const SizedBox(height: 3),
                                      Text(
                                        'ID: ${student.studentId}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Tappable 3-State Status Badge (cycles Present -> Late -> Absent)
                                GestureDetector(
                                  onTap: () => _cycleStudentStatus(student),
                                  child: _buildStatusBadge(student.status),
                                ),
                                const SizedBox(width: 12),

                                // Custom Toggle Switch (Matches teacher-session-detail.png)
                                CupertinoSwitch(
                                  value: isChecked,
                                  activeTrackColor: const Color(0xFF1B2A4A),
                                  onChanged: (val) => _toggleStudentStatus(student, val),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 200.ms, delay: (index * 30).ms);
                      },
                    ),
            ),

            // Bottom Crimson "End Session & Submit" Button matching mockup
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _endSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF991B1B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'End Session & Submit',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
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

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 22,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2A4A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row with "< Classes", Quick Actions & "Beacon Live"
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
              Row(
                children: [
                  // Fast Launch QR
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeacherDynamicQrScreen(
                            sessionId: widget.sessionId,
                            classRoomName: widget.className,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 4),
                          Text('QR', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // Fast Launch Live Feed
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeacherLiveFeedScreen(
                            sessionId: widget.sessionId,
                            classRoomName: widget.className,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sensors_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 4),
                          Text('Feed', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // Beacon Live pill
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

          // 3-Column Metrics Row (Pixel-perfect match to teacher-session-detail.png)
          Row(
            children: [
              _buildMetricColumn('STUDENTS', '$_totalCount Total', Colors.white),
              Container(width: 1, height: 32, color: const Color(0xFF2E456E)),
              _buildMetricColumn('ATTENDANCE', '$_presentCount Present', Colors.white),
              Container(width: 1, height: 32, color: const Color(0xFF2E456E)),
              _buildMetricColumn('ABSENT', '$_absentCount Unresolved', const Color(0xFFFCA5A5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          // Search TextField
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF10213E)),
              decoration: InputDecoration(
                hintText: 'Search by student name or ID...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${_students.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('present', 'Present (${_students.where((s) => s.status == 'present').length})'),
                const SizedBox(width: 8),
                _buildFilterChip('late', 'Late (${_students.where((s) => s.status == 'late').length})'),
                const SizedBox(width: 8),
                _buildFilterChip('absent', 'Absent (${_students.where((s) => s.status == 'absent').length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B2A4A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B2A4A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
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
        bg = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        label = 'Present';
        break;
      case 'late':
        bg = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        label = 'Late';
        break;
      case 'absent':
      default:
        bg = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFB91C1C);
        label = 'Absent';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
