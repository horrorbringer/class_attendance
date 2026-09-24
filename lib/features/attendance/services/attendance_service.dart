import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../teacher/repositories/teacher_repository.dart';
import '../models/attendance_models.dart';

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  final teacherRepo = ref.watch(teacherRepositoryProvider);
  return AttendanceService(teacherRepo);
});

class AttendanceService {
  final TeacherRepository _teacherRepository;

  AttendanceService(this._teacherRepository);

  /// Flow 5: Teacher Bulk Attendance Override
  /// `POST /api/teacher/sessions/<session_id>/attendance/bulk/`
  Future<BulkAttendanceResponse> submitBulkAttendance({
    required int sessionId,
    required List<BulkAttendanceItem> records,
  }) async {
    return _teacherRepository.submitBulkAttendance(
      sessionId: sessionId,
      records: records,
    );
  }

  /// Flow 4: Teacher 1-Click Manual Override
  /// `PATCH /api/teacher/attendance/<record_id>/`
  Future<void> overrideAttendance({
    required int recordId,
    required String status,
  }) async {
    return _teacherRepository.overrideAttendance(
      recordId: recordId,
      status: status,
    );
  }

  /// Conclude session
  /// `POST /api/teacher/sessions/<session_id>/end/`
  Future<void> endSession(int sessionId) async {
    return _teacherRepository.endSession(sessionId);
  }
}
