import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../attendance/models/attendance_models.dart';
import '../repositories/teacher_repository.dart';
import 'teacher_dynamic_qr_screen.dart';

/// Class selection option
class ClassRoomOption {
  final int id;
  final String name;
  final String code;

  const ClassRoomOption({
    required this.id,
    required this.name,
    required this.code,
  });
}

/// Modal Bottom Sheet for Teachers to create an on-demand class session
/// Supports Flow 2: POST /api/teacher/sessions/
class TeacherCreateSessionSheet extends ConsumerStatefulWidget {
  final List<ClassRoomOption>? initialClasses;
  final VoidCallback? onSessionCreated;

  const TeacherCreateSessionSheet({
    super.key,
    this.initialClasses,
    this.onSessionCreated,
  });

  static Future<void> show(
    BuildContext context, {
    List<ClassRoomOption>? classes,
    VoidCallback? onCreated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TeacherCreateSessionSheet(
        initialClasses: classes,
        onSessionCreated: onCreated,
      ),
    );
  }

  @override
  ConsumerState<TeacherCreateSessionSheet> createState() => _TeacherCreateSessionSheetState();
}

class _TeacherCreateSessionSheetState extends ConsumerState<TeacherCreateSessionSheet> {
  // Available classes (defaults with standard curriculum classrooms)
  late List<ClassRoomOption> _classes;
  late int _selectedClassId;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  bool _autoGenerateQr = true;
  int _qrExpiryMinutes = 120;

  bool _isSubmitting = false;
  String? _errorMessage;

  final List<int> _expiryOptions = [30, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();

    _classes = widget.initialClasses ??
        const [
          ClassRoomOption(id: 1, name: 'Computer Science 101', code: 'CS-101'),
          ClassRoomOption(id: 2, name: 'Physics Lab II', code: 'PHY-201'),
          ClassRoomOption(id: 3, name: 'Advanced Mathematics', code: 'MATH-301'),
          ClassRoomOption(id: 4, name: 'Introduction to AI', code: 'CS-402'),
        ];

    _selectedClassId = _classes.first.id;
    _selectedDate = DateTime.now();

    final now = TimeOfDay.now();
    _startTime = now;
    // End time 2 hours from now
    _endTime = TimeOfDay(hour: (now.hour + 2) % 24, minute: now.minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _formatDisplayTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B2A4A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF10213E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B2A4A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF10213E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Adjust end time to be 2 hours after start if end is earlier
        final startMinutes = picked.hour * 60 + picked.minute;
        final endMinutes = _endTime.hour * 60 + _endTime.minute;
        if (endMinutes <= startMinutes) {
          _endTime = TimeOfDay(hour: (picked.hour + 2) % 24, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B2A4A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF10213E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submitCreateSession() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final startTimeStr = _formatTimeOfDay(_startTime);
    final endTimeStr = _formatTimeOfDay(_endTime);

    final request = CreateSessionRequest(
      classRoom: _selectedClassId,
      date: dateStr,
      startTime: startTimeStr,
      endTime: endTimeStr,
      autoGenerateQr: _autoGenerateQr,
      qrExpiryMinutes: _qrExpiryMinutes,
    );

    final selectedClass = _classes.firstWhere(
      (c) => c.id == _selectedClassId,
      orElse: () => _classes.first,
    );

    try {
      final createdSession = await ref.read(teacherRepositoryProvider).createSession(request);
      final int newSessionId = createdSession.id > 0
          ? createdSession.id
          : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

      if (mounted) {
        widget.onSessionCreated?.call();
        Navigator.pop(context);

        // Show success snackbar with action to immediately launch dynamic QR
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Session created for ${selectedClass.name}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10213E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Launch QR',
              textColor: const Color(0xFF38BDF8),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherDynamicQrScreen(
                      sessionId: newSessionId,
                      classRoomName: selectedClass.name,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ??
          e.response?.data?['detail'] ??
          e.message ??
          'Failed to create session';
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = msg.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'An unexpected error occurred: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
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

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Class Session',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10213E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Start an on-demand session & live attendance',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_task_rounded,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Classroom Picker
              Text(
                'Classroom',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedClassId,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    items: _classes.map((cls) {
                      return DropdownMenuItem<int>(
                        value: cls.id,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cls.code,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cls.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10213E),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedClassId = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Date Picker
              Text(
                'Date',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10213E),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar_outlined, size: 18, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Time Range (Start Time & End Time)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Time',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDisplayTime(_startTime),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10213E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Time',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDisplayTime(_endTime),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10213E),
                                    ),
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
              ),
              const SizedBox(height: 20),

              // QR Code Configuration Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-Generate Dynamic QR',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF10213E),
                                  ),
                                ),
                                Text(
                                  'Rotates code to prevent proxy check-ins',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _autoGenerateQr,
                          activeTrackColor: const Color(0xFF2563EB),
                          onChanged: (val) => setState(() => _autoGenerateQr = val),
                        ),
                      ],
                    ),

                    if (_autoGenerateQr) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'QR Expiry Duration',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          Text(
                            '$_qrExpiryMinutes min',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _expiryOptions.map((mins) {
                          final isSelected = _qrExpiryMinutes == mins;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => setState(() => _qrExpiryMinutes = mins),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF1B2A4A) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF1B2A4A) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${mins}m',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? Colors.white : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitCreateSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2A4A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Create & Start',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
