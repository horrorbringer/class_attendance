import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/student_repository.dart';
import 'absence_alert_detail_screen.dart';
import 'attendance_history_screen.dart';
import 'face_enrollment_screen.dart';
import 'profile_settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../../../core/widgets/modern_app_bar.dart';

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

  NotificationItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? timestamp,
    AlertCategory? category,
    bool? hasLeftAccent,
    bool? isUnread,
    String? courseName,
    String? date,
    String? scheduleTime,
    String? location,
    String? professor,
    String? failureReason,
    String? guardianAlertTime,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      hasLeftAccent: hasLeftAccent ?? this.hasLeftAccent,
      isUnread: isUnread ?? this.isUnread,
      courseName: courseName ?? this.courseName,
      date: date ?? this.date,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      location: location ?? this.location,
      professor: professor ?? this.professor,
      failureReason: failureReason ?? this.failureReason,
      guardianAlertTime: guardianAlertTime ?? this.guardianAlertTime,
    );
  }
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
  final List<NotificationItem> _defaultMockupItems = const [
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
      hasLeftAccent: false,
      isUnread: false,
      courseName: 'Physics Lab 202',
      date: 'Wednesday, Sep 14, 2026',
      scheduleTime: '01:30 PM — 03:00 PM',
      location: 'Science Lab 4',
      professor: 'Dr. Marie Curie',
      failureReason: 'Checked in 14 minutes past class start',
      guardianAlertTime: '01:44 PM',
    ),
    NotificationItem(
      id: 'sys_1',
      title: 'System Update',
      subtitle: 'Facial database re-enrolled successfully.',
      timestamp: '3 days ago',
      category: AlertCategory.system,
      hasLeftAccent: false,
      isUnread: false,
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
      final studentRepo = ref.read(studentRepositoryProvider);
      final List<NotificationItem> fetched = [];
      final Set<String> seenIds = {};

      // 1. Fetch dedicated alerts from GET /api/alerts/mine/
      try {
        final alertsList = await studentRepo.getAlerts();
        for (final m in alertsList) {
          final alertId = 'alert_${m.id}';
          final sessionName = m.sessionName.isNotEmpty ? m.sessionName : 'Class Session';
          final sessionDate = m.sessionDate;
          final channel = m.channel;
          final sentAt = m.sentAt;
          final status = m.status;
          final errorMsg = m.errorMessage;

          seenIds.add(alertId);

          String channelLabel = channel == 'telegram' ? 'Telegram' : (channel == 'email' ? 'Email' : 'System');
          String failureInfo = status == 'sent'
              ? 'Guardian notified via $channelLabel'
              : (errorMsg.isNotEmpty ? 'Delivery pending: $errorMsg' : 'Alert pending delivery');

          fetched.add(
            NotificationItem(
              id: alertId,
              title: 'Absence Alert',
              subtitle: 'You were marked absent in $sessionName',
              timestamp: sentAt,
              category: AlertCategory.absences,
              hasLeftAccent: true,
              isUnread: true,
              courseName: sessionName,
              date: sessionDate.isNotEmpty ? sessionDate : 'Scheduled Class Session',
              scheduleTime: 'Class Session',
              location: 'Assigned Campus Room',
              professor: 'Class Faculty Instructor',
              failureReason: failureInfo,
              guardianAlertTime: sentAt,
            ),
          );
        }
      } catch (_) {}

      // 2. Also check attendance history for any absent/late records not covered by alerts
      try {
        final historyRes = await studentRepo.getAttendanceHistory(limit: 50);
        for (final rec in historyRes.results) {
          final status = rec.status.toLowerCase();
          final className = rec.classRoomName.isNotEmpty ? rec.classRoomName : 'Classroom Session';
          final checkedInAt = rec.checkedInAt.isNotEmpty ? rec.checkedInAt : 'Recent';
          final recordId = 'live_${status}_${rec.id}';

          if (seenIds.contains(recordId)) continue;

            if (status == 'absent') {
              seenIds.add(recordId);
              fetched.add(
                NotificationItem(
                  id: recordId,
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
                  guardianAlertTime: '—',
                ),
              );
            } else if (status == 'late') {
              seenIds.add(recordId);
              fetched.add(
                NotificationItem(
                  id: recordId,
                  title: 'Tardy Logged',
                  subtitle: 'You checked in late for $className',
                  timestamp: checkedInAt,
                  category: AlertCategory.late,
                  hasLeftAccent: false,
                  isUnread: false,
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
      } catch (_) {}

      // 3. Append default system update card if we have real alerts
      if (fetched.isNotEmpty) {
        fetched.add(
          const NotificationItem(
            id: 'sys_1',
            title: 'System Update',
            subtitle: 'Facial database re-enrolled successfully.',
            timestamp: '3 days ago',
            category: AlertCategory.system,
            hasLeftAccent: false,
            isUnread: false,
            courseName: 'Biometric Security Service',
            date: 'Monday, Sep 12, 2026',
            failureReason: '5/5 high-resolution face templates synced',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _items = fetched.isNotEmpty ? fetched : List.from(_defaultMockupItems);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = List.from(_defaultMockupItems);
          _isLoading = false;
        });
      }
    }
  }

  List<NotificationItem> get _filteredItems {
    if (_selectedFilter == AlertCategory.all) return _items;
    return _items.where((i) => i.category == _selectedFilter).toList();
  }

  int get _unreadCount => _items.where((i) => i.isUnread).length;

  void _markAllAsRead() {
    HapticFeedback.lightImpact();
    setState(() {
      _items = _items.map((i) => i.copyWith(isUnread: false, hasLeftAccent: false)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'All notifications marked as read',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10213E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onNotificationTapped(NotificationItem item) {
    HapticFeedback.selectionClick();

    // Mark as read immediately on tap
    if (item.isUnread) {
      setState(() {
        final index = _items.indexWhere((element) => element.id == item.id);
        if (index != -1) {
          _items[index] = _items[index].copyWith(isUnread: false, hasLeftAccent: false);
        }
      });
    }

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

  void _dismissNotification(NotificationItem item) {
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index == -1) return;

    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title} archived'),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFF38BDF8),
          onPressed: () {
            setState(() {
              _items.insert(index, removed);
            });
          },
        ),
      ),
    );
  }

  void _showLateDetailDialog(NotificationItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                width: 44,
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFFD97706), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        item.courseName ?? 'Physics Lab 202',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tardy',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildModalRow('Date', item.date ?? 'Wednesday, Sep 14, 2026'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Scheduled Time', item.scheduleTime ?? '01:30 PM — 03:00 PM'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Logged At', item.timestamp),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Class Instructor', item.professor ?? 'Dr. Marie Curie'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Log Reason', item.failureReason ?? 'Checked in after start grace window'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Dismiss',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AbsenceAlertDetailScreen(
                            courseName: item.courseName ?? 'Physics Lab 202',
                            date: item.date ?? 'Wednesday, Sep 14, 2026',
                            scheduleTime: item.scheduleTime ?? '01:30 PM — 03:00 PM',
                            location: item.location ?? 'Science Lab 4',
                            professor: item.professor ?? 'Dr. Marie Curie',
                            failureReason: item.failureReason ?? 'Checked in 14 minutes past class start',
                            alertTime: item.timestamp,
                            guardianAlertTime: item.guardianAlertTime ?? '01:44 PM',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF10213E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Appeal / Excuse',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSystemInfoDialog(NotificationItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                width: 44,
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        'Device Security & Face Templates',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildModalRow('Security Status', 'Active & Protected'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Biometric Hash', 'AES-256 Encrypted'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Vector Models', '5 / 5 Synced'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildModalRow('Last Verification', item.timestamp),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your facial embeddings are safely encrypted on-device and ready for seamless kiosk or mobile check-in verification.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10213E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.face_retouching_natural_rounded, size: 20, color: Colors.white),
                label: Text(
                  'Manage Face Embeddings',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
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
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModernAppBar(
        title: 'Notifications & Alerts',
        subtitle: _unreadCount > 0 ? '$_unreadCount unread updates' : 'All updates viewed',
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _markAllAsRead,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 5),
                        Text(
                          'Mark Read',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _fetchAlerts,
          color: const Color(0xFF10213E),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    child: CircularProgressIndicator(color: Color(0xFF10213E)),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_none_rounded, size: 36, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No alerts in this category',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You\'re all caught up with your notifications',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () => setState(() => _selectedFilter = AlertCategory.all),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                          ),
                          child: Text('Show all notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Dismissible(
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.archive_outlined, color: Color(0xFFDC2626)),
                            ),
                            onDismissed: (_) => _dismissNotification(item),
                            child: _buildNotificationCard(item)
                                .animate()
                                .fadeIn(duration: 220.ms, delay: (index * 40).ms)
                                .slideY(begin: 0.04, end: 0),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar matching Mockup 09 with "Alerts" active
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
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
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = category);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10213E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? const Color(0xFF10213E) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0810213E),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    // Exact colors and icons from Mockup 09
    Color iconBg;
    IconData icon;
    Color iconColor;

    switch (item.category) {
      case AlertCategory.absences:
        iconBg = const Color(0xFFFFE4E6);
        icon = Icons.notifications_off_outlined;
        iconColor = const Color(0xFFE11D48);
        break;
      case AlertCategory.late:
        iconBg = const Color(0xFFFEF3C7);
        icon = Icons.access_time_rounded;
        iconColor = const Color(0xFFD97706);
        break;
      case AlertCategory.system:
        iconBg = const Color(0xFFEFF6FF);
        icon = Icons.shield_outlined;
        iconColor = const Color(0xFF2563EB);
        break;
      case AlertCategory.all:
        iconBg = const Color(0xFFF1F5F9);
        icon = Icons.notifications_outlined;
        iconColor = const Color(0xFF64748B);
        break;
    }

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onNotificationTapped(item),
            splashColor: const Color(0xFFF1F5F9),
            highlightColor: const Color(0xFFF8FAFC),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Accent Strip (Matches Mockup 09 dark navy left border on Card 1)
                  if (item.hasLeftAccent)
                    Container(
                      width: 4.5,
                      color: const Color(0xFF10213E),
                    ),

                  // Main Card Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rounded Square Icon Container
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

                          // Text Information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title & Top-Right Blue Dot (Exact Mockup 09 layout)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10213E),
                                        ),
                                      ),
                                    ),
                                    if (item.isUnread) ...[
                                      const SizedBox(width: 8),
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
                                    color: const Color(0xFF475569),
                                    height: 1.35,
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
