import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/attendance_models.dart';

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  final dio = ref.watch(dioProvider);
  return AttendanceService(dio);
});

class AttendanceService {
  final Dio _dio;

  AttendanceService(this._dio);

  /// Flow 5: Teacher Bulk Attendance Override
  /// `POST /api/teacher/sessions/<session_id>/attendance/bulk/`
  Future<BulkAttendanceResponse> submitBulkAttendance({
    required int sessionId,
    required List<BulkAttendanceItem> records,
  }) async {
    final response = await _dio.post(
      ApiConstants.sessionBulkAttendance(sessionId),
      data: {
        'records': records.map((e) => e.toJson()).toList(),
      },
    );
    return BulkAttendanceResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Flow 4: Teacher 1-Click Manual Override
  /// `PATCH /api/teacher/attendance/<record_id>/`
  Future<void> overrideAttendance({
    required int recordId,
    required String status,
  }) async {
    await _dio.patch(
      ApiConstants.teacherAttendanceOverride(recordId),
      data: {'status': status},
    );
  }

  /// Conclude session
  /// `POST /api/teacher/sessions/<session_id>/end/`
  Future<void> endSession(int sessionId) async {
    await _dio.post(ApiConstants.sessionEnd(sessionId));
  }
}
