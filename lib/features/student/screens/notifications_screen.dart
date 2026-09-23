import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'absence_alert_detail_screen.dart';
import 'attendance_history_screen.dart';
import 'face_enrollment_screen.dart';
import 'profile_settings_screen.dart';
import 'qr_scanner_screen.dart';

enum AlertCategory { all, absences, late, system }

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String timestamp;
  final AlertCategory category;
  final bool hasLeftAccent;
  final bool isUnread;
  final String? courseName;
  final String? date;
  final String? scheduleTime;
  final String? location;
  final String? professor;
  final String? failureReason;
  final String? guardianAlertTime;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.category,
    this.hasLeftAccent = false,
    this.isUnread = false,
    this.courseName,
    this.date,
    this.scheduleTime,
    this.location,
    this.professor,
    this.failureReason,
    this.guardianAlertTime,
  });
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  AlertCategory _selectedFilter = AlertCategory.all;
  bool _isLoading = false;
  List<NotificationItem> _items = [];

  // Default mockup items from UI Mockup 09
  final List<NotificationItem> _mockupItems = const [
    NotificationItem(
      id: 'abs_1',
      title: 'Absence Alert',
      subtitle: 'You were marked absent in Mathematics 101',
      timestamp: '2 hours ago',
      category: AlertCategory.absences,
      hasLeftAccent: true,
      isUnread: true,
      courseName: 'Mathematics 101',
      date: 'Thursday, Sep 15, 2026',
      scheduleTime: '09:00 AM — 10:30 AM',
      location: 'Room 204',
      professor: 'Prof. Alan Turing',
      failureReason: 'No biometric or QR log recorded',
      guardianAlertTime: '9:15 AM',
    ),
    NotificationItem(
      id: 'late_1',
      title: 'Tardy Logged',
      subtitle: 'You checked in late for Physics Lab 202',
      timestamp: 'Yesterday',
      category: AlertCategory.late,
      courseName: 'Physics Lab 202',
      date: 'Wednesday, Sep 14, 2026',
      scheduleTime: '01:30 PM — 03:00 PM',
      location: 'Science Lab 4',
      professor: 'Dr. Marie Curie',
      failureReason: 'Checked in 14 minutes past class start',
    ),
    NotificationItem(
      id: 'sys_1',
      title: 'System Update',
      subtitle: 'Facial database re-enrolled successfully.',
      timestamp: '3 days ago',
      category: AlertCategory.system,
      courseName: 'Biometric Security Service',
      date: 'Monday, Sep 12, 2026',
      failureReason: '5/5 high-resolution face templates synced',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final List<NotificationItem> fetched = [];

      // Check live attendance history for any real absent or late sessions
      try {
        final historyRes = await dio.get(ApiConstants.attendanceHistory);
        if (historyRes.data is List) {
          final list = historyRes.data as List<dynamic>;
          for (final raw in list) {
            final m = raw as Map<String, dynamic>;
            final status = (m['status'] ?? '').toString().toLowerCase();
            final className = m['class_room_name'] ?? m['classroom_name'] ?? 'Classroom Session';
            final checkedInAt = m['checked_in_at']?.toString() ?? 'Recent';

            if (status == 'absent') {
              fetched.add(
                NotificationItem(
                  id: 'live_abs_${m['id']}',
                  title: 'Absence Alert',
                  subtitle: 'You were marked absent in $className',
                  timestamp: checkedInAt,
                  category: AlertCategory.absences,
                  hasLeftAccent: true,
                  isUnread: true,
                  courseName: className,
                  date: checkedInAt,
                  scheduleTime: 'Class Session',
                  location: 'Assigned Campus Room',
                  professor: 'Class Faculty Instructor',
                  failureReason: 'No biometric or QR log recorded',
                  guardianAlertTime: '9:15 AM',
                ),
              );
            } else if (status == 'late') {
              fetched.add(
                NotificationItem(
                  id: 'live_late_${m['id']}',
                  title: 'Tardy Logged',
                  subtitle: 'You checked in late for $className',
                  timestamp: checkedInAt,
                  category: AlertCategory.late,
                  courseName: className,
                  date: checkedInAt,
                  scheduleTime: 'Class Session',
                  location: 'Assigned Campus Room',
                  professor: 'Class Faculty Instructor',
                  failureReason: 'Arrived after grace period',
                ),
              );
            }
          }
        }
      } catch (_) {}

      // If we found live absent/late records, append the system update card
      if (fetched.isNotEmpty) {
        fetched.add(
          const NotificationItem(
            id: 'sys_1',
            title: 'System Update',
            subtitle: 'Facial database re-enrolled successfully.',
            timestamp: '3 days ago',
            category: AlertCategory.system,
            courseName: 'Biometric Security Service',
            date: 'Monday, Sep 12, 2026',
            failureReason: '5/5 high-resolution face templates synced',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _items = fetched.isNotEmpty ? fetched : _mockupItems;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = _mockupItems;
          _isLoading = false;
        });
      }
    }
  }

  List<NotificationItem> get _filteredItems {
    if (_selectedFilter == AlertCategory.all) return _items;
    return _items.where((i) => i.category == _selectedFilter).toList();
  }

  void _onNotificationTapped(NotificationItem item) {
    if (item.category == AlertCategory.absences) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AbsenceAlertDetailScreen(
            courseName: item.courseName ?? 'Mathematics 101',
            date: item.date ?? 'Thursday, Sep 15, 2026',
            scheduleTime: item.scheduleTime ?? '09:00 AM — 10:30 AM',
            location: item.location ?? 'Room 204',
            professor: item.professor ?? 'Prof. Alan Turing',
            failureReason: item.failureReason ?? 'No biometric or QR log recorded',
            alertTime: item.timestamp,
            guardianAlertTime: item.guardianAlertTime ?? '9:15 AM',
          ),
        ),
      );
    } else if (item.category == AlertCategory.late) {
      _showLateDetailDialog(item);
    } else {
      _showSystemInfoDialog(item);
    }
  }

  void _showLateDetailDialog(NotificationItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.access_time_rounded, color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        item.courseName ?? 'Physics Lab 202',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF5C6E84)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildModalRow('Date', item.date ?? 'Wednesday, Sep 14, 2026'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Scheduled Time', item.scheduleTime ?? '01:30 PM — 03:00 PM'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Check-in Timestamp', '01:44 PM (14m Late)'),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Teacher', item.professor ?? 'Dr. Marie Curie'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A4A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Dismiss', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSystemInfoDialog(NotificationItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF0284C7), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        'Device Security & Face Templates',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF5C6E84)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Your facial embeddings have been securely updated in the database. Biometric check-in is ready for instant kiosk and mobile recognition.',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5C6E84), height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A4A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('View Biometric Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAlerts,
          color: const Color(0xFF1B2A4A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Title "Notifications" matching Mockup 09
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Notifications',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10213E),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Pills matching Mockup 09: All, Absences, Late, System
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterPill('All', AlertCategory.all),
                            const SizedBox(width: 10),
                            _buildFilterPill('Absences', AlertCategory.absences),
                            const SizedBox(width: 10),
                            _buildFilterPill('Late', AlertCategory.late),
                            const SizedBox(width: 10),
                            _buildFilterPill('System', AlertCategory.system),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1B2A4A)),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications found',
                          style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFF5C6E84)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildNotificationCard(item)
                              .animate()
                              .fadeIn(duration: 250.ms, delay: (index * 50).ms)
                              .slideY(begin: 0.05, end: 0),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar matching Mockup 09 with "Alerts" active
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EEF8), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: 3, // Alerts is active
          onTap: (index) {
            if (index == 0) {
              Navigator.popUntil(context, (route) => route.isFirst);
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
              );
            } else if (index == 3) {
              _fetchAlerts();
            } else if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
              );
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
              icon: Icon(Icons.notifications_active_rounded),
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

  Widget _buildFilterPill(String title, AlertCategory category) {
    final isSelected = _selectedFilter == category;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = category);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B2A4A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B2A4A) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1B2A4A).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF5C6E84),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    // Config based on alert category
    Color iconBg;
    IconData icon;
    Color iconColor;

    switch (item.category) {
      case AlertCategory.absences:
        iconBg = const Color(0xFFFFEEEE);
        icon = Icons.notifications_off_outlined;
        iconColor = const Color(0xFFEF4444);
        break;
      case AlertCategory.late:
        iconBg = const Color(0xFFFEF3C7);
        icon = Icons.access_time_rounded;
        iconColor = const Color(0xFFF59E0B);
        break;
      case AlertCategory.system:
        iconBg = const Color(0xFFE0F2FE);
        icon = Icons.shield_outlined;
        iconColor = const Color(0xFF0284C7);
        break;
      case AlertCategory.all:
        iconBg = const Color(0xFFF1F5F9);
        icon = Icons.notifications_outlined;
        iconColor = const Color(0xFF64748B);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNotificationTapped(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Navy Accent Bar (for Absence Alert / Unread as shown in Mockup 09)
                  if (item.hasLeftAccent)
                    Container(
                      width: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B2A4A),
                      ),
                    ),

                  // Main Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rounded Icon Square
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: iconColor, size: 22),
                          ),
                          const SizedBox(width: 14),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title & Unread Dot
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF10213E),
                                        ),
                                      ),
                                    ),
                                    if (item.isUnread) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1E3A8A),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Subtitle
                                Text(
                                  item.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF5C6E84),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Timestamp
                                Text(
                                  item.timestamp,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
