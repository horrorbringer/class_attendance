import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../attendance/models/attendance_models.dart';
import '../../student/repositories/student_repository.dart';
import '../../../core/widgets/modern_app_bar.dart';

class TeacherStudentProfileScreen extends ConsumerStatefulWidget {
  final int? studentPk;
  final String studentName;
  final String studentId;
  final String grade;
  final String attendanceRate;
  final String absences;
  final String warnings;
  final String email;
  final String guardianName;
  final String guardianPhone;
  final String? guardianTelegramId;

  const TeacherStudentProfileScreen({
    super.key,
    this.studentPk,
    this.studentName = 'Marcus Vance',
    this.studentId = '202611',
    this.grade = 'Grade 11-A',
    this.attendanceRate = '94.2%',
    this.absences = '1 Day',
    this.warnings = '0 Active',
    this.email = 'marcus.vance@school.edu',
    this.guardianName = 'Robert Vance',
    this.guardianPhone = '(555) 019-2834',
    this.guardianTelegramId,
  });

  @override
  ConsumerState<TeacherStudentProfileScreen> createState() => _TeacherStudentProfileScreenState();
}

class _TeacherStudentProfileScreenState extends ConsumerState<TeacherStudentProfileScreen> {
  StudentAttendanceReport? _report;
  bool _isLoadingReport = false;

  @override
  void initState() {
    super.initState();
    _loadLiveReport();
  }

  Future<void> _loadLiveReport() async {
    if (widget.studentPk == null) return;
    setState(() => _isLoadingReport = true);

    try {
      final rep = await ref.read(studentRepositoryProvider).getStudentReport(widget.studentPk!);
      if (mounted) {
        setState(() {
          _report = rep;
          _isLoadingReport = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingReport = false);
      }
    }
  }

  String get _displayName => _report?.studentName.isNotEmpty == true ? _report!.studentName : widget.studentName;
  String get _displayGrade => _report?.classRoom.isNotEmpty == true ? _report!.classRoom : widget.grade;
  String get _displayAttendanceRate => _report != null ? '${_report!.attendanceRate.toStringAsFixed(1)}%' : widget.attendanceRate;
  String get _displayAbsences => _report != null ? '${_report!.absentCount} ${_report!.absentCount == 1 ? 'Day' : 'Days'}' : widget.absences;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: ModernAppBar(
        title: 'Student Profile',
        subtitle: 'Academic Records & Attendance',
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Editing student academic records...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Text(
                    'Edit Profile',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingReport)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Color(0xFF2563EB),
                ),

              // Avatar & Student Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF1B2A4A),
                    backgroundImage: const NetworkImage(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
                    ),
                    child: Text(
                      _displayName.isNotEmpty ? _displayName[0] : 'S',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_displayGrade • ID: ${widget.studentId}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              // 3 Metric Badges Row
              Row(
                children: [
                  _buildMetricCard('ATTENDANCE', _displayAttendanceRate, const Color(0xFF10213E)),
                  const SizedBox(width: 12),
                  _buildMetricCard('ABSENCES', _displayAbsences, const Color(0xFFB91C1C)),
                  const SizedBox(width: 12),
                  _buildMetricCard('WARNINGS', widget.warnings, const Color(0xFFB45309)),
                ],
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

              if (_report != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('Present', '${_report!.presentCount}', const Color(0xFF10B981)),
                      Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                      _buildMiniStat('Late', '${_report!.lateCount}', const Color(0xFFF59E0B)),
                      Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                      _buildMiniStat('Absent', '${_report!.absentCount}', const Color(0xFFEF4444)),
                      Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                      _buildMiniStat('Total', '${_report!.totalRecordedSessions}', const Color(0xFF64748B)),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),
              ],

              const SizedBox(height: 24),

              // Section: Contact Information
              Text(
                'Contact Information',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(18),
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
                  children: [
                    _buildContactRow('Email', widget.email),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildContactRow('Guardian Name', widget.guardianName),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildGuardianPhoneRow(widget.guardianPhone),
                    if (widget.guardianTelegramId != null && widget.guardianTelegramId!.isNotEmpty) ...[
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildGuardianTelegramRow(widget.guardianTelegramId!),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 24),

              // Section: Records
              Text(
                '${_displayName.split(' ').first}\'s Records',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 12),

              // Attendance History Cards
              _buildHistoryRecordCard('Advanced Mathematics', 'Recent Session', 'Present', const Color(0xFFD1FAE5), const Color(0xFF047857)),
              const SizedBox(height: 10),
              _buildHistoryRecordCard('Physics Lab II', 'Prior Session', 'Absent', const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
              const SizedBox(height: 10),
              _buildHistoryRecordCard('Intro to Computer Science', 'Prior Session', 'Present', const Color(0xFFD1FAE5), const Color(0xFF047857)),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 3,
          onTap: (index) {
            Navigator.pop(context);
          },
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF10213E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianPhoneRow(String phone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Guardian Phone',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10213E),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
                  if (clean.isNotEmpty) {
                    final uri = Uri.parse('tel:$clean');
                    try {
                      await launchUrl(uri);
                    } catch (_) {}
                  }
                },
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
                      const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Call',
                        style: GoogleFonts.inter(
                          fontSize: 11,
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
        ),
      ],
    );
  }

  Widget _buildGuardianTelegramRow(String telegramId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Guardian Telegram',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  telegramId.startsWith('@') ? telegramId : '@$telegramId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final clean = telegramId.replaceAll('@', '').trim();
                  if (clean.isNotEmpty) {
                    final uri = Uri.parse('https://t.me/$clean');
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send_rounded, size: 12, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(
                        'Message',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRecordCard(String className, String date, String status, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
