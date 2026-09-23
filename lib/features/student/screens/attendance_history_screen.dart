import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/models/attendance_models.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AttendanceRecord> _records = [];
  String _selectedFilter = 'all'; // 'all', 'present', 'late', 'absent'

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiConstants.attendanceHistory);
      final list = response.data as List<dynamic>;

      setState(() {
        _records = list.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Failed to load attendance history';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    if (_selectedFilter == 'all') return _records;
    return _records.where((r) => r.status.toLowerCase() == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All (${_records.length})', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Present (${_records.where((r) => r.status == 'present').length})',
                  'present',
                  color: AppTheme.present,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Late (${_records.where((r) => r.status == 'late').length})',
                  'late',
                  color: AppTheme.late,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Absent (${_records.where((r) => r.status == 'absent').length})',
                  'absent',
                  color: AppTheme.absent,
                ),
              ],
            ),
          ),

          // Main Content List
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black87 : AppTheme.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: color ?? AppTheme.primary,
      backgroundColor: AppTheme.surface,
      side: BorderSide(
        color: isSelected ? Colors.transparent : AppTheme.surfaceBorder,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.absent),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchHistory, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    final displayList = _filteredRecords;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined, size: 56, color: AppTheme.textMuted.withAlpha(120)),
            const SizedBox(height: 12),
            const Text(
              'No attendance records found',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: displayList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = displayList[index];
          return _buildRecordCard(item);
        },
      ),
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    Color statusColor;
    IconData statusIcon;

    switch (record.status.toLowerCase()) {
      case 'present':
        statusColor = AppTheme.present;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'late':
        statusColor = AppTheme.late;
        statusIcon = Icons.access_time_filled_rounded;
        break;
      default:
        statusColor = AppTheme.absent;
        statusIcon = Icons.cancel_rounded;
    }

    String formattedDate = record.checkedInAt;
    try {
      final dt = DateTime.parse(record.checkedInAt).toLocal();
      formattedDate = DateFormat('EEE, MMM d, yyyy • hh:mm a').format(dt);
    } catch (_) {}

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.classRoomName.isNotEmpty ? record.classRoomName : 'Class Session',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(120)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        record.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        record.method == 'face'
                            ? Icons.face_rounded
                            : (record.method == 'manual' ? Icons.edit_rounded : Icons.qr_code_rounded),
                        size: 13,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified via ${record.method.toUpperCase()}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (record.confidenceScore != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Score: ${(record.confidenceScore! * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
