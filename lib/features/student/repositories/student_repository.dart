import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../attendance/models/attendance_models.dart';

abstract class StudentRepository {
  Future<List<StudentScheduleSession>> getTodaySchedule();
  Future<StudentAttendanceReport> getStudentReport(int studentId);
  Future<PaginatedAttendanceResponse> getAttendanceHistory({
    String? status,
    int limit = 20,
    int offset = 0,
  });
  Future<List<StudentAlertItem>> getAlerts();
  Future<CheckinResponse> checkinQr(String qrToken, {String? deviceId});
  Future<CheckinResponse> checkinFace(String imagePath, {int? sessionId, String? deviceId});
  Future<FaceEnrollmentResponse> enrollFace({
    required List<String> imagePaths,
    String? studentId,
  });
}

class StudentRepositoryImpl implements StudentRepository {
  final Dio _dio;

  StudentRepositoryImpl(this._dio);

  @override
  Future<List<StudentScheduleSession>> getTodaySchedule() async {
    final response = await _dio.get(ApiConstants.studentScheduleToday);
    if (response.data is List) {
      final list = response.data as List<dynamic>;
      return list
          .map((e) => StudentScheduleSession.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<StudentAttendanceReport> getStudentReport(int studentId) async {
    final response = await _dio.get(ApiConstants.studentReport(studentId));
    return StudentAttendanceReport.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PaginatedAttendanceResponse> getAttendanceHistory({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final Map<String, dynamic> queryParams = {
      'limit': limit,
      'offset': offset,
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _dio.get(
      ApiConstants.attendanceHistory,
      queryParameters: queryParams,
    );

    return PaginatedAttendanceResponse.fromJson(response.data);
  }

  @override
  Future<List<StudentAlertItem>> getAlerts() async {
    final response = await _dio.get(ApiConstants.studentAlerts);
    if (response.data is List) {
      final list = response.data as List<dynamic>;
      return list
          .map((e) => StudentAlertItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<CheckinResponse> checkinQr(String qrToken, {String? deviceId}) async {
    final payload = <String, dynamic>{'qr_token': qrToken};
    if (deviceId != null && deviceId.isNotEmpty) {
      payload['device_id'] = deviceId;
    }
    final response = await _dio.post(
      ApiConstants.checkinQr,
      data: payload,
    );
    return CheckinResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CheckinResponse> checkinFace(String imagePath, {int? sessionId, String? deviceId}) async {
    final map = <String, dynamic>{
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: 'face_checkin_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    };
    if (sessionId != null) {
      map['session_id'] = sessionId;
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      map['device_id'] = deviceId;
    }

    final formData = FormData.fromMap(map);
    final response = await _dio.post(
      ApiConstants.checkinFace,
      data: formData,
    );
    return CheckinResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<FaceEnrollmentResponse> enrollFace({
    required List<String> imagePaths,
    String? studentId,
  }) async {
    final formData = FormData();
    if (studentId != null && studentId.isNotEmpty) {
      formData.fields.add(MapEntry('student_id', studentId));
    }

    for (int i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(
            path,
            filename: 'face_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        ),
      );
    }

    final response = await _dio.post(
      ApiConstants.faceEnroll,
      data: formData,
    );
    return FaceEnrollmentResponse.fromJson(response.data as Map<String, dynamic>);
  }
}

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return StudentRepositoryImpl(dio);
});
