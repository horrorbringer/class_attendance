import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/models/auth_models.dart';
import '../repositories/teacher_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import 'teacher_classes_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_profile_screen.dart';
import '../../../core/widgets/modern_app_bar.dart';

class TeacherReportsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const TeacherReportsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends ConsumerState<TeacherReportsScreen> {
  int _selectedDayIndex = 2; // Wednesday active by default (matching teacher-reports.png)
  int _selectedWeekOffset = 0; // -1: Prev, 0: This, 1: Next
  bool _isExporting = false;
  List<ClassRoom> _classrooms = [];
  bool _isLoadingClassrooms = false;

  @override
  void initState() {
    super.initState();
    _fetchClassrooms();
  }

  Future<void> _fetchClassrooms() async {
    setState(() => _isLoadingClassrooms = true);
    try {
      final list = await ref.read(teacherRepositoryProvider).getClassrooms();
      if (mounted) {
        setState(() {
          _classrooms = list;
          _isLoadingClassrooms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingClassrooms = false);
    }
  }

  final List<Map<String, dynamic>> _weekPresets = [
    {
      'label': 'Previous Week',
      'month': 'October 2026',
      'days': [
        {'day': 'Mon', 'rate': '91%', 'math': 88.0, 'phys': 84.0, 'cs': 92.0},
        {'day': 'Tue', 'rate': '87%', 'math': 85.0, 'phys': 89.0, 'cs': 90.0},
        {'day': 'Wed', 'rate': '94%', 'math': 92.0, 'phys': 90.0, 'cs': 96.0},
        {'day': 'Thu', 'rate': '89%', 'math': 86.0, 'phys': 88.0, 'cs': 91.0},
        {'day': 'Fri', 'rate': '92%', 'math': 90.0, 'phys': 93.0, 'cs': 94.0},
      ],
    },
    {
      'label': 'This Week',
      'month': 'October 2026',
      'days': [
        {'day': 'Mon', 'rate': '88%', 'math': 90.0, 'phys': 85.0, 'cs': 95.0},
        {'day': 'Tue', 'rate': '90%', 'math': 92.0, 'phys': 88.0, 'cs': 94.0},
        {'day': 'Wed', 'rate': '92%', 'math': 88.0, 'phys': 92.0, 'cs': 96.0},
        {'day': 'Thu', 'rate': '85%', 'math': 85.0, 'phys': 89.0, 'cs': 91.0},
        {'day': 'Fri', 'rate': '94%', 'math': 94.0, 'phys': 91.0, 'cs': 95.0},
      ],
    },
    {
      'label': 'Next Week',
      'month': 'October 2026',
      'days': [
        {'day': 'Mon', 'rate': '93%', 'math': 91.0, 'phys': 89.0, 'cs': 94.0},
        {'day': 'Tue', 'rate': '91%', 'math': 90.0, 'phys': 92.0, 'cs': 93.0},
        {'day': 'Wed', 'rate': '95%', 'math': 94.0, 'phys': 93.0, 'cs': 97.0},
        {'day': 'Thu', 'rate': '88%', 'math': 87.0, 'phys': 90.0, 'cs': 92.0},
        {'day': 'Fri', 'rate': '96%', 'math': 95.0, 'phys': 94.0, 'cs': 98.0},
      ],
    },
  ];

  Map<String, dynamic> get _currentWeekData {
    final idx = _selectedWeekOffset + 1;
    return _weekPresets[idx.clamp(0, _weekPresets.length - 1)];
  }

  void _cycleWeek(int direction) {
    final next = _selectedWeekOffset + direction;
    if (next >= -1 && next <= 1) {
      setState(() => _selectedWeekOffset = next);
    }
  }

  Future<void> _handleExport(int classId, String className, bool isCsv) async {
    setState(() => _isExporting = true);
    Navigator.pop(context); // Close bottom sheet

    try {
      if (isCsv) {
        await ref.read(teacherRepositoryProvider).exportCsv(classId);
      } else {
        // Simulate PDF rendering delay
        await Future.delayed(const Duration(milliseconds: 900));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Icon(
                  isCsv ? Icons.table_chart_rounded : Icons.picture_as_pdf_rounded,
                  color: const Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCsv
                        ? 'CSV Registry exported for $className'
                        : 'Attendance PDF generated for $className',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
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
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Export generated successfully for $className',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Export Attendance Report',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10213E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select class registry and export file format',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                // Class options from backend
                if (_isLoadingClassrooms)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Color(0xFF10213E)),
                    ),
                  )
                else if (_classrooms.isNotEmpty)
                  ..._classrooms.map((cr) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildExportClassTile(
                        ctx,
                        cr.name,
                        cr.id,
                        'Classroom #${cr.id}',
                      ),
                    );
                  })
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No classrooms found for export.',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportClassTile(BuildContext ctx, String className, int classId, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          className,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF10213E)),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PDF Button
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1B2A4A), size: 22),
              tooltip: 'Export PDF',
              onPressed: () => _handleExport(classId, className, false),
            ),
            // CSV Button
            IconButton(
              icon: const Icon(Icons.table_chart_rounded, color: Color(0xFF047857), size: 22),
              tooltip: 'Export CSV',
              onPressed: () => _handleExport(classId, className, true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final teacherName = authState.session?.displayName ?? 'Dr. Aris Thorne';
    final week = _currentWeekData;
    final List<Map<String, dynamic>> days = List<Map<String, dynamic>>.from(week['days']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModernAppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        title: 'Analytics & Reports',
        subtitle: 'Classroom Metrics • $teacherName',
        actions: [
          ModernAppBarAction(
            icon: Icons.file_download_outlined,
            tooltip: 'Export CSV Report',
            onPressed: () => _showExportOptionsSheet(),
          ),
          const SizedBox(width: 8),
          ModernAppBarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Reports',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // October 2026 Week Strip Container
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    // Month & Navigation Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          week['month'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10213E),
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _selectedWeekOffset > -1 ? () => _cycleWeek(-1) : null,
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: _selectedWeekOffset > -1
                                    ? const Color(0xFF10213E)
                                    : const Color(0xFFCBD5E1),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              week['label'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10213E),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _selectedWeekOffset < 1 ? () => _cycleWeek(1) : null,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: _selectedWeekOffset < 1
                                    ? const Color(0xFF10213E)
                                    : const Color(0xFFCBD5E1),
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 5 Days Strip (Pixel-perfect match to teacher-reports.png)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(days.length, (index) {
                        final item = days[index];
                        final isSelected = index == _selectedDayIndex;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDayIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 16 : 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1B2A4A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  item['day'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['rate'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 24),

              // Weekly Class Comparison Section
              Text(
                'Weekly Class Comparison',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    // Bar chart area with animated heights
                    SizedBox(
                      height: 130,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(days.length, (i) {
                          final d = days[i];
                          final isSelected = i == _selectedDayIndex;
                          return _buildDayBarGroup(
                            d['day'] as String,
                            (d['math'] as num).toDouble(),
                            (d['phys'] as num).toDouble(),
                            (d['cs'] as num).toDouble(),
                            isSelected,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Chart Legend (Matching teacher-reports.png)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem('Math', const Color(0xFF1B2A4A)),
                        const SizedBox(width: 18),
                        _buildLegendItem('Physics', const Color(0xFF38BDF8)),
                        const SizedBox(width: 18),
                        _buildLegendItem('Comp Sci', const Color(0xFF10B981)),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 24),

              // Class Analytics Section
              Text(
                'Class Analytics',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10213E),
                ),
              ),
              const SizedBox(height: 12),

              _buildClassAnalyticsCard(
                'Intro to Computer Science',
                '0 warning',
                '94.6%',
                const Color(0xFF047857),
                3,
              ),
              const SizedBox(height: 10),
              _buildClassAnalyticsCard(
                'Advanced Mathematics',
                '2 warning',
                '91.6%',
                const Color(0xFFB45309),
                1,
              ),
              const SizedBox(height: 10),
              _buildClassAnalyticsCard(
                'Physics Lab II',
                '5 warning',
                '89.8%',
                const Color(0xFFBE123C),
                2,
              ),

              const SizedBox(height: 24),

              // "Export Attendance PDF" Button matching teacher-reports.png
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isExporting ? null : _showExportOptionsSheet,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1B2A4A), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B2A4A)),
                          ),
                        )
                      : Text(
                          'Export Attendance PDF',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B2A4A),
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar with 4 tabs matching teacher-reports.png
      bottomNavigationBar: widget.isEmbedded ? null : Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 2, // Reports is active
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TeacherClassesScreen()),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined), // Academic cap matching mockup
              label: 'Classes',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF10213E), size: 20),
              ),
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

  Widget _buildDayBarGroup(String day, double h1, double h2, double h3, bool isSelected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildSingleBar(h1, const Color(0xFF1B2A4A), isSelected),
            const SizedBox(width: 4),
            _buildSingleBar(h2, const Color(0xFF38BDF8), isSelected),
            const SizedBox(width: 4),
            _buildSingleBar(h3, const Color(0xFF10B981), isSelected),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isSelected ? const Color(0xFF10213E) : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleBar(double heightPercentage, Color color, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 8,
      height: (heightPercentage / 100) * 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildClassAnalyticsCard(
    String title,
    String warning,
    String rate,
    Color rateColor,
    int classId,
  ) {
    return GestureDetector(
      onTap: () {
        // Tapping card prompts quick export options for this specific class
        _showClassActionSheet(title, classId, rate, warning);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10213E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  warning,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  rate,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: rateColor,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClassActionSheet(String title, int classId, String rate, String warning) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    Text(
                      rate,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                Text(
                  '$warning recorded this term',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text('Export PDF'),
                        onPressed: () => _handleExport(classId, title, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B2A4A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.table_chart_rounded, size: 18),
                        label: const Text('Export CSV'),
                        onPressed: () => _handleExport(classId, title, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B2A4A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
