import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'attendance_history_screen.dart';
import 'profile_settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../../../core/widgets/modern_app_bar.dart';

class AbsenceAlertDetailScreen extends StatefulWidget {
  final String courseName;
  final String date;
  final String scheduleTime;
  final String location;
  final String professor;
  final String failureReason;
  final String alertTime;
  final String guardianAlertTime;

  const AbsenceAlertDetailScreen({
    super.key,
    this.courseName = 'Mathematics 101',
    this.date = 'Thursday, Sep 15, 2026',
    this.scheduleTime = '09:00 AM — 10:30 AM',
    this.location = 'Room 204',
    this.professor = 'Prof. Alan Turing',
    this.failureReason = 'No biometric or QR log recorded',
    this.alertTime = 'Today, 9:30 AM',
    this.guardianAlertTime = '9:15 AM',
  });

  @override
  State<AbsenceAlertDetailScreen> createState() => _AbsenceAlertDetailScreenState();
}

class _AbsenceAlertDetailScreenState extends State<AbsenceAlertDetailScreen> {
  // Tracks submission state for UX feedback
  bool _hasSubmittedExcuse = false;
  String _submittedCategory = 'Medical / Sick Leave';
  String _submittedNote = '';
  String? _attachedFileName;

  void _openContactTeacherModal() {
    HapticFeedback.lightImpact();
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

            // Teacher Profile Header
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF10213E),
                  child: Text(
                    widget.professor.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.professor,
                        style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                      ),
                      Text(
                        'Faculty of Computer Science & Mathematics',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Contact Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildContactRow(
                    Icons.email_outlined,
                    'Email',
                    'alan.turing@university.edu',
                    onCopy: () => _copyToClipboard('alan.turing@university.edu', 'Email copied'),
                  ),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildContactRow(
                    Icons.location_on_outlined,
                    'Office',
                    '${widget.location} / Science Wing 3B',
                    onCopy: () => _copyToClipboard('${widget.location} / Science Wing 3B', 'Office location copied'),
                  ),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildContactRow(
                    Icons.access_time_rounded,
                    'Office Hours',
                    'Mon & Thu 02:00 PM — 04:00 PM',
                  ),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildContactRow(
                    Icons.send_rounded,
                    'Alert Channel',
                    'Automated Telegram dispatch active',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Direct Send Email Action
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _copyToClipboard('alan.turing@university.edu', 'Draft recipient copied to clipboard');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Email drafted to ${widget.professor} for ${widget.courseName}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF10213E),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10213E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Compose Email to Faculty',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String title, String value, {VoidCallback? onCopy}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onCopy,
            tooltip: 'Copy',
          ),
      ],
    );
  }

  void _openExcuseNoteModal() {
    HapticFeedback.lightImpact();
    final noteController = TextEditingController(text: _submittedNote);
    String selectedCategory = _submittedCategory;
    String? localAttachment = _attachedFileName;
    final categories = [
      'Medical / Sick Leave',
      'Transit Delay',
      'Family Emergency',
      'Official School Event',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 18),
                  Text(
                    _hasSubmittedExcuse ? 'Update Excuse Note' : 'Submit Excuse Note',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF10213E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.courseName} • ${widget.date}',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),

                  // Reason Category selection
                  Text(
                    'Reason Category',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCategory = cat);
                        },
                        selectedColor: const Color(0xFF10213E),
                        backgroundColor: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF10213E) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Explanation Text Area
                  Text(
                    'Explanation / Message',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF10213E)),
                    decoration: InputDecoration(
                      hintText: 'Describe why you were absent or unable to complete biometric check-in...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF10213E), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attachment / Proof
                  Text(
                    'Attach Supporting Document (Optional)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10213E)),
                  ),
                  const SizedBox(height: 8),
                  if (localAttachment != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF475569)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localAttachment!,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() => localAttachment = null),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModalState(() {
                          localAttachment = 'Medical_Certificate_${DateTime.now().millisecondsSinceEpoch % 10000}.pdf';
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              'Upload Medical Certificate or Proof',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasSubmittedExcuse = true;
                          _submittedCategory = selectedCategory;
                          _submittedNote = noteController.text.trim();
                          _attachedFileName = localAttachment;
                        });
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('Excuse note submitted to ${widget.professor} for review.'),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10213E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Submit for Review',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: ModernAppBar(
        title: 'Alert Detail',
        subtitle: widget.courseName,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Alert Detail Card (matching Mockup 10)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge & Timestamp Header matching Mockup 10
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Absence Alert',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFE11D48),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.alertTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Course Name
                    Text(
                      widget.courseName,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10213E),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Thin Divider
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 16),

                    // Key-Value Rows matching Mockup 10
                    _buildDetailRow('Date', widget.date),
                    const SizedBox(height: 14),
                    _buildDetailRow('Schedule Time', widget.scheduleTime),
                    const SizedBox(height: 14),
                    _buildDetailRow('Location', widget.location),
                    const SizedBox(height: 14),
                    _buildDetailRow('Professor', widget.professor),
                    const SizedBox(height: 14),
                    _buildDetailRow(
                      'Failure Reason',
                      widget.failureReason,
                      valueColor: const Color(0xFF10213E),
                      valueFontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0),

              const SizedBox(height: 18),

              // Guardian Alert Banner matching Mockup 10
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Automatic alert sent to guardian at ${widget.guardianAlertTime}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, end: 0),

              // Excuse Note Submitted Feedback Pill if submitted
              if (_hasSubmittedExcuse) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Excuse Note Submitted • Under Review',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                            Text(
                              'Category: $_submittedCategory${_attachedFileName != null ? ' • 1 Attachment' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.98, 0.98)),
              ],

              const SizedBox(height: 24),

              // Primary Solid Navy Button: Contact Teacher
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _openContactTeacherModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10213E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Contact Teacher',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.04, end: 0),

              const SizedBox(height: 12),

              // Secondary Outlined Button: Submit Excuse Note
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _openExcuseNoteModal,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _hasSubmittedExcuse ? 'Update Excuse Note' : 'Submit Excuse Note',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10213E),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, end: 0),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Fixed Bottom Navigation Bar matching Mockup 10
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
              Navigator.pop(context);
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

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueFontWeight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: valueFontWeight ?? FontWeight.w600,
              color: valueColor ?? const Color(0xFF10213E),
            ),
          ),
        ),
      ],
    );
  }
}
