import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../repositories/student_repository.dart';
import '../../attendance/models/attendance_models.dart';
import 'notifications_screen.dart';
import 'profile_settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../../../core/widgets/modern_app_bar.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<AttendanceRecord> _records = [];

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  // Pagination state
  static const int _pageSize = 20;
  int _offset = 0;
  bool _hasMore = true;

  // Status filter: null = all, or 'present', 'late', 'absent'
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
        _hasMore = true;
        if (!loadMore) _records = [];
      });
    }

    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      final paginatedRes = await studentRepo.getAttendanceHistory(
        status: _statusFilter,
        limit: _pageSize,
        offset: loadMore ? _offset : 0,
      );

      final newRecords = paginatedRes.results;
      _hasMore = (_offset + _pageSize) < paginatedRes.count;

      setState(() {
        if (loadMore) {
          _records.addAll(newRecords);
        } else {
          _records = newRecords;
        }
        _offset = _records.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Failed to load attendance history';
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onStatusFilterChanged(String? newFilter) {
    setState(() => _statusFilter = newFilter);
    _fetchHistory();
  }

  List<AttendanceRecord> get _filteredRecords {
    if (_selectedDate == null) {
      return _records;
    }
    return _records.where((r) {
      try {
        final dt = DateTime.parse(r.checkedInAt).toLocal();
        return dt.year == _selectedDate!.year &&
            dt.month == _selectedDate!.month &&
            dt.day == _selectedDate!.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // Map each date to its worst or best attendance status
  Map<int, String> get _monthAttendanceMap {
    final Map<int, String> map = {};
    for (final r in _records) {
      try {
        final dt = DateTime.parse(r.checkedInAt).toLocal();
        if (dt.year == _focusedMonth.year && dt.month == _focusedMonth.month) {
          final status = r.status.toLowerCase();
          // Priority: absent > late > present
          final existing = map[dt.day];
          if (existing == null || existing == 'present') {
            map[dt.day] = status;
          }
        }
      } catch (_) {}
    }
    return map;
  }

  void _onPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDate = null;
    });
  }

  void _onNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat('MMMM yyyy').format(_focusedMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: ModernAppBar(
        title: 'Attendance History',
        subtitle: 'Academic Term: Fall 2026',
        actions: [
          ModernAppBarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Records',
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _fetchHistory,
          color: const Color(0xFF1A3258),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Calendar Card matching docs/ui/08 — Attendance History.png
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      // Month + Arrow controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            monthTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10213E),
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _onPreviousMonth,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.chevron_left_rounded, size: 22, color: Color(0xFF10213E)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _onNextMonth,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.chevron_right_rounded, size: 22, color: Color(0xFF10213E)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Day of Week Header: M  T  W  T  F (Monday - Friday matching mockup)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _CalendarHeaderCell('M'),
                          _CalendarHeaderCell('T'),
                          _CalendarHeaderCell('W'),
                          _CalendarHeaderCell('T'),
                          _CalendarHeaderCell('F'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Grid of Days
                      _buildMonthCalendarGrid(),

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFEEF3FA), height: 1),
                      const SizedBox(height: 12),

                      // Legend Row matching docs/ui/08 — Attendance History.png
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendItem('Present', const Color(0xFF10B981)),
                          _buildLegendItem('Absent', const Color(0xFFEF4444)),
                          _buildLegendItem('Late', const Color(0xFFF59E0B)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Status filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Present', 'present'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Late', 'late'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Absent', 'absent'),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Recent Activity Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    if (_selectedDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: Text(
                          'Show All',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Activity Records List
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Color(0xFF1A3258)),
                    ),
                  )
                else if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFEF4444)),
                          const SizedBox(height: 8),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _fetchHistory, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                else if (_filteredRecords.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
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
                      children: [
                        const Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text(
                          'No attendance records found',
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7C93)),
                        ),
                      ],
                    ),
                  )
                else
                  ..._filteredRecords.map((record) => _buildActivityCard(record)),

                // Load More button for pagination
                if (!_isLoading && _hasMore && _filteredRecords.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: _isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: Color(0xFF1A3258), strokeWidth: 2.5),
                            )
                          : OutlinedButton(
                              onPressed: () => _fetchHistory(loadMore: true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1A3258),
                                side: const BorderSide(color: Color(0xFFD6E4F8)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Load More',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),

      // Bottom Navigation Bar with History Tab Active
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 2, // History is active
          onTap: (index) {
            if (index == 0) {
              Navigator.pop(context);
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            } else if (index == 2) {
              _fetchHistory();
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            } else if (index == 4) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
              );
            } else {
              Navigator.pop(context);
            }
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
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Check-in',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              label: 'Alerts',
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

  Widget _buildFilterChip(String label, String? value) {
    final isActive = _statusFilter == value;
    Color chipBg;
    Color chipText;

    if (isActive) {
      if (value == 'present') {
        chipBg = const Color(0xFFD1FAE5);
        chipText = const Color(0xFF059669);
      } else if (value == 'late') {
        chipBg = const Color(0xFFFEF3C7);
        chipText = const Color(0xFFD97706);
      } else if (value == 'absent') {
        chipBg = const Color(0xFFFEE2E2);
        chipText = const Color(0xFFDC2626);
      } else {
        chipBg = const Color(0xFF1A3258);
        chipText = Colors.white;
      }
    } else {
      chipBg = Colors.white;
      chipText = const Color(0xFF5C6E84);
    }

    return GestureDetector(
      onTap: () => _onStatusFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? chipBg : const Color(0xFFE2EAF4),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: chipText,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCalendarGrid() {
    // Generate dates for current month (Monday to Friday columns)
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfWeek = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1 = Monday ... 7 = Sunday
    final attendanceMap = _monthAttendanceMap;

    final List<Widget> dayWidgets = [];

    // Fill leading empty cells for days before the 1st (Mon-Fri)
    // If weekday is Saturday (6) or Sunday (7), adjust
    final leadDays = (firstDayOfWeek <= 5) ? (firstDayOfWeek - 1) : 0;
    for (int i = 0; i < leadDays; i++) {
      dayWidgets.add(const SizedBox(height: 44));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      // Skip weekends to match Monday-Friday 5-column layout of the design
      if (date.weekday > 5) continue;

      final isSelected = _selectedDate != null &&
          _selectedDate!.year == date.year &&
          _selectedDate!.month == date.month &&
          _selectedDate!.day == date.day;

      final status = attendanceMap[day];

      Color? dotColor;
      if (status == 'present') dotColor = const Color(0xFF10B981);
      if (status == 'late') dotColor = const Color(0xFFF59E0B);
      if (status == 'absent') dotColor = const Color(0xFFEF4444);

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDate = null;
              } else {
                _selectedDate = date;
              }
            });
          },
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEBF3FE) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: const Color(0xFF3B82F6), width: 1.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: const Color(0xFF10213E),
                  ),
                ),
                const SizedBox(height: 3),
                if (dotColor != null)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }

  Widget _buildActivityCard(AttendanceRecord record) {
    Color pillBg;
    Color pillText;
    String statusLabel;

    switch (record.status.toLowerCase()) {
      case 'present':
        pillBg = const Color(0xFFD1FAE5);
        pillText = const Color(0xFF059669);
        statusLabel = 'Present';
        break;
      case 'late':
        pillBg = const Color(0xFFFEF3C7);
        pillText = const Color(0xFFD97706);
        statusLabel = 'Late';
        break;
      default:
        pillBg = const Color(0xFFFEE2E2);
        pillText = const Color(0xFFDC2626);
        statusLabel = 'Absent';
    }

    String formattedDate = 'Recent Date';
    String formattedTime = '-- : --';

    try {
      final dt = DateTime.parse(record.checkedInAt).toLocal();
      formattedDate = DateFormat('MMM d, yyyy').format(dt);
      if (record.status.toLowerCase() != 'absent') {
        formattedTime = DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Top Row: Date on Left, Status Pill on Right matching docs/ui/08 — Attendance History.png
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8898AA),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(10),
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

          const SizedBox(height: 8),

          // Bottom Row: Subject / Classroom Name on Left, Time on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  record.classRoomName.isNotEmpty ? record.classRoomName : 'Class Session',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10213E),
                  ),
                ),
              ),
              Text(
                formattedTime,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7C93),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          // Verification method tag
          Row(
            children: [
              Icon(
                record.method == 'face' ? Icons.face_rounded : Icons.qr_code_rounded,
                size: 13,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 4),
              Text(
                'Verified via ${record.method.toUpperCase()}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8C9BAE)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF5C6E84),
          ),
        ),
      ],
    );
  }
}

class _CalendarHeaderCell extends StatelessWidget {
  final String day;
  const _CalendarHeaderCell(this.day);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Center(
        child: Text(
          day,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8898AA),
          ),
        ),
      ),
    );
  }
}
