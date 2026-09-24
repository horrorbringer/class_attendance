import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../attendance/models/attendance_models.dart';

abstract class TeacherRepository {
  Future<List<TeacherClassSession>> getTodayClasses();
  Future<TeacherClassSession> createSession(CreateSessionRequest request);
  Future<SessionRosterResponse> getSessionRoster(int sessionId);
  Future<LiveFeedData> getSessionLiveFeed(int sessionId, {String? since});
  Future<DynamicQrData> getDynamicQr(int sessionId);
  Future<void> overrideAttendance({
    required int recordId,
    required String status,
  });
  Future<BulkAttendanceResponse> submitBulkAttendance({
    required int sessionId,
    required List<BulkAttendanceItem> records,
  });
  Future<void> endSession(int sessionId);
  Future<String> exportCsv(int classId, {String? startDate, String? endDate});
}

class TeacherRepositoryImpl implements TeacherRepository {
  final Dio _dio;

  TeacherRepositoryImpl(this._dio);

  @override
  Future<List<TeacherClassSession>> getTodayClasses() async {
    final response = await _dio.get(ApiConstants.teacherTodayClasses);
    if (response.data is List) {
      final list = response.data as List<dynamic>;
      return list
          .map((e) => TeacherClassSession.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<TeacherClassSession> createSession(CreateSessionRequest request) async {
    final response = await _dio.post(
      ApiConstants.teacherSessions,
      data: request.toJson(),
    );
    return TeacherClassSession.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<SessionRosterResponse> getSessionRoster(int sessionId) async {
    final response = await _dio.get(ApiConstants.sessionRoster(sessionId));
    return SessionRosterResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<LiveFeedData> getSessionLiveFeed(int sessionId, {String? since}) async {
    final response = await _dio.get(
      ApiConstants.sessionLiveFeed(sessionId),
      queryParameters: since != null ? {'since': since} : null,
    );
    return LiveFeedData.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<DynamicQrData> getDynamicQr(int sessionId) async {
    final response = await _dio.get(ApiConstants.sessionDynamicQr(sessionId));
    return DynamicQrData.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> overrideAttendance({
    required int recordId,
    required String status,
  }) async {
    await _dio.patch(
      ApiConstants.teacherAttendanceOverride(recordId),
      data: {'status': status},
    );
  }

  @override
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

  @override
  Future<void> endSession(int sessionId) async {
    await _dio.post(ApiConstants.sessionEnd(sessionId));
  }

  @override
  Future<String> exportCsv(int classId, {String? startDate, String? endDate}) async {
    final Map<String, dynamic> queryParams = {};
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['end_date'] = endDate;
    }

    final response = await _dio.get(
      ApiConstants.exportCsv(classId),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return response.data?.toString() ?? '';
  }
}

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TeacherRepositoryImpl(dio);
});
