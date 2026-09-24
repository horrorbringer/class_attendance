import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../repositories/teacher_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/modern_app_bar.dart';
import '../../attendance/models/attendance_models.dart';
import 'teacher_dynamic_qr_screen.dart';

class TeacherLiveFeedScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final String classRoomName;

  const TeacherLiveFeedScreen({
    super.key,
    required this.sessionId,
    required this.classRoomName,
  });

  @override
  ConsumerState<TeacherLiveFeedScreen> createState() => _TeacherLiveFeedScreenState();
}

class _TeacherLiveFeedScreenState extends ConsumerState<TeacherLiveFeedScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Timer? _pollingTimer;

  LiveFeedData? _feedData;
  List<RosterStudent> _rosterList = [];
  bool _isLoadingRoster = false;
  bool _isSessionEnded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _fetchLiveFeed();
    _fetchRoster();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _tabController.dispose();
    super.dispose();
  }

  /// Pause polling when app goes to background to prevent battery drain.
  /// Resume polling when teacher returns to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _fetchLiveFeed();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchLiveFeed() async {
    try {
      final feed = await ref.read(teacherRepositoryProvider).getSessionLiveFeed(widget.sessionId);
      if (mounted) {
        setState(() {
          _feedData = feed;
          _isSessionEnded = _feedData!.isEnded;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchRoster() async {
    setState(() => _isLoadingRoster = true);
    try {
      final rosterRes = await ref.read(teacherRepositoryProvider).getSessionRoster(widget.sessionId);

      if (mounted) {
        setState(() {
          _rosterList = rosterRes.roster;
          _isLoadingRoster = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRoster = false);
      }
    }
  }

  Future<void> _overrideStudentStatus(RosterStudent student, String newStatus) async {
    try {
      final teacherRepo = ref.read(teacherRepositoryProvider);

      if (student.recordId != null) {
        // Direct PATCH override
        await teacherRepo.overrideAttendance(
          recordId: student.recordId!,
          status: newStatus,
        );
      } else {
        // Bulk override endpoint
        await teacherRepo.submitBulkAttendance(
          sessionId: widget.sessionId,
          records: [
            BulkAttendanceItem(studentId: student.studentId, status: newStatus),
          ],
        );
      }

      _fetchLiveFeed();
      _fetchRoster();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.studentName} marked as $newStatus'),
            backgroundColor: AppTheme.present,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppTheme.absent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Class Session?'),
        content: const Text(
          'Ending this session will mark all remaining unmarked students as absent and trigger automated notification alerts to guardians.\n\nAre you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.absent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(teacherRepositoryProvider).endSession(widget.sessionId);

      setState(() => _isSessionEnded = true);
      _fetchLiveFeed();
      _fetchRoster();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class session ended and absence alerts dispatched.'),
            backgroundColor: AppTheme.present,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end session: $e'), backgroundColor: AppTheme.absent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: ModernAppBar(
        title: '${widget.classRoomName} Live',
        subtitle: 'Real-time Verification Stream',
        actions: [
          ModernAppBarAction(
            icon: Icons.qr_code_rounded,
            tooltip: 'Show Dynamic QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherDynamicQrScreen(
                    sessionId: widget.sessionId,
                    classRoomName: widget.classRoomName,
                  ),
                ),
              );
            },
          ),
          if (!_isSessionEnded) ...[
            const SizedBox(width: 8),
            ModernAppBarAction(
              icon: Icons.stop_circle_outlined,
              iconColor: const Color(0xFFDC2626),
              tooltip: 'End Class Session',
              onPressed: _endSession,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10213E),
          labelColor: const Color(0xFF10213E),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelColor: const Color(0xFF64748B),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Live Feed & Ticker'),
            Tab(text: 'Classroom Roster'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveFeedTab(),
          _buildRosterTab(),
        ],
      ),
    );
  }

  Widget _buildLiveFeedTab() {
    if (_feedData == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final recentCheckins = _feedData!.recentCheckins;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchLiveFeed();
      },
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        children: [
          // Stat Counters Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCounter('Enrolled', _feedData!.totalEnrolled, AppTheme.textPrimary),
                    _buildStatCounter('Present', _feedData!.presentCount, AppTheme.present),
                    _buildStatCounter('Late', _feedData!.lateCount, AppTheme.late),
                    _buildStatCounter('Absent', _feedData!.absentCount, AppTheme.absent),
                    _buildStatCounter('Unmarked', _feedData!.unmarkedCount, AppTheme.unmarked),
                  ],
                ),
                if (_isSessionEnded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.absent.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SESSION CONCLUDED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.absent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dynamic QR Quick Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 36, color: AppTheme.primary),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dynamic Projector QR', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Broadcast rotating dynamic QR code to classroom',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherDynamicQrScreen(
                          sessionId: widget.sessionId,
                          classRoomName: widget.classRoomName,
                        ),
                      ),
                    );
                  },
                  child: const Text('Project'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Real-time Check-ins Ticker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Live Check-ins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppTheme.present, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('Live 3s Polling', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (recentCheckins.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, size: 40, color: AppTheme.textMuted.withAlpha(120)),
                    const SizedBox(height: 12),
                    const Text('Waiting for student check-ins...', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...recentCheckins.map((checkin) {
              final isPresent = checkin.status == 'present';
              final statusColor = isPresent ? AppTheme.present : AppTheme.late;

              String checkinTime = '';
              if (checkin.checkedInAt != null) {
                try {
                  final dt = DateTime.parse(checkin.checkedInAt!).toLocal();
                  checkinTime = DateFormat('hh:mm:ss a').format(dt);
                } catch (_) {}
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withAlpha(40),
                    child: Icon(
                      checkin.method == 'face' ? Icons.face_rounded : Icons.qr_code_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  title: Text(checkin.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID: ${checkin.studentId} • Via ${checkin.method.toUpperCase()} $checkinTime'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withAlpha(100)),
                    ),
                    child: Text(
                      checkin.status.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRosterTab() {
    if (_isLoadingRoster) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_rosterList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchRoster,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No students in class roster.\nPull down to refresh.', textAlign: TextAlign.center)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRoster,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        itemCount: _rosterList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final student = _rosterList[i];
          Color statusColor;

          switch (student.attendanceStatus.toLowerCase()) {
            case 'present':
              statusColor = AppTheme.present;
              break;
            case 'late':
              statusColor = AppTheme.late;
              break;
            case 'absent':
              statusColor = AppTheme.absent;
              break;
            default:
              statusColor = AppTheme.unmarked;
          }

          return Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withAlpha(30),
                child: Text(
                  student.studentName.isNotEmpty ? student.studentName[0] : 'S',
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              title: Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('ID: ${student.studentId} • ${student.attendanceStatus.toUpperCase()}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  student.attendanceStatus.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guardian Contact: ${student.guardianContact}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      if (student.checkedInAt != null)
                        Text('Checked in at: ${student.checkedInAt} (${student.method ?? "unknown"})',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 12),
                      const Text('Manual Status Override:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.present),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _overrideStudentStatus(student, 'present'),
                              child: const Text('Present', style: TextStyle(color: AppTheme.present, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.late),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _overrideStudentStatus(student, 'late'),
                              child: const Text('Late', style: TextStyle(color: AppTheme.late, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.absent),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _overrideStudentStatus(student, 'absent'),
                              child: const Text('Absent', style: TextStyle(color: AppTheme.absent, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
