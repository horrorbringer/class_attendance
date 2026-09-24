import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_attendance/core/network/system_repository.dart';
import 'package:class_attendance/features/attendance/models/attendance_models.dart';
import 'package:class_attendance/features/attendance/services/attendance_service.dart';
import 'package:class_attendance/features/auth/repositories/auth_repository.dart';
import 'package:class_attendance/features/student/repositories/student_repository.dart';
import 'package:class_attendance/features/teacher/repositories/teacher_repository.dart';

class MockDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AuthRepository', () {
    test('login sends credentials and returns UserSession', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/auth/login/'));
        expect(options.method, 'POST');
        final data = options.data as Map<String, dynamic>;
        expect(data['username'], 'student_dara');
        expect(data['password'], 'StudentPass123!');

        final jsonResp = {
          'token': 'test_token_123',
          'user_id': 14,
          'username': 'student_dara',
          'role': 'student',
          'student': {
            'id': 2,
            'student_id': 'STU001',
            'name': 'Dara Pich',
          },
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepositoryImpl(dio);
      final session = await repo.login('student_dara', 'StudentPass123!');

      expect(session.token, 'test_token_123');
      expect(session.userId, 14);
      expect(session.isStudent, true);
      expect(session.displayName, 'Dara Pich');
    });

    test('getStudentProfile returns StudentProfile', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/students/me/'));
        expect(options.method, 'GET');

        final jsonResp = {
          'id': 2,
          'student_id': 'STU001',
          'full_name': 'Dara Pich',
          'class_room': {'id': 1, 'name': 'CS-101'},
          'face_embeddings_count': 3,
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepositoryImpl(dio);
      final profile = await repo.getStudentProfile();

      expect(profile.id, 2);
      expect(profile.studentId, 'STU001');
      expect(profile.fullName, 'Dara Pich');
      expect(profile.faceEmbeddingsCount, 3);
      expect(profile.classRoom?.name, 'CS-101');
    });

    test('changePassword sends old and new password', () async {
      final dio = Dio();
      var called = false;
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/auth/change-password/'));
        expect(options.method, 'POST');
        final data = options.data as Map<String, dynamic>;
        expect(data['old_password'], 'old123');
        expect(data['new_password'], 'new123');
        expect(data['confirm_password'], 'new123');
        called = true;

        return ResponseBody.fromString(
          jsonEncode({'message': 'Password changed successfully.'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepositoryImpl(dio);
      await repo.changePassword(
        oldPassword: 'old123',
        newPassword: 'new123',
        confirmPassword: 'new123',
      );
      expect(called, true);
    });
  });

  group('StudentRepository', () {
    test('getTodaySchedule returns list of sessions', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/students/schedule/today/'));
        final jsonResp = [
          {
            'id': 10,
            'class_room': 'Computer Science 101',
            'date': '2026-09-24',
            'start_time': '08:00:00',
            'end_time': '10:00:00',
            'is_qr_active': true,
            'is_checked_in': true,
            'my_status': 'present',
            'my_method': 'qr',
          }
        ];
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = StudentRepositoryImpl(dio);
      final schedule = await repo.getTodaySchedule();

      expect(schedule.length, 1);
      expect(schedule.first.id, 10);
      expect(schedule.first.classRoom, 'Computer Science 101');
      expect(schedule.first.isCheckedIn, true);
      expect(schedule.first.myStatus, 'present');
    });

    test('getStudentReport returns StudentAttendanceReport', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/reports/student/2/'));
        final jsonResp = {
          'student_id': 'STU001',
          'student_name': 'Dara Pich',
          'class_room': 'CS-101',
          'total_recorded_sessions': 24,
          'present_count': 21,
          'late_count': 2,
          'absent_count': 1,
          'attendance_rate': 87.5,
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = StudentRepositoryImpl(dio);
      final report = await repo.getStudentReport(2);

      expect(report.studentId, 'STU001');
      expect(report.attendanceRate, 87.5);
      expect(report.presentCount, 21);
      expect(report.totalRecordedSessions, 24);
    });

    test('getAttendanceHistory formats query parameters and parses results', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/attendance/history/'));
        expect(options.queryParameters['status'], 'present');
        expect(options.queryParameters['limit'], 10);
        expect(options.queryParameters['offset'], 20);

        final jsonResp = {
          'count': 45,
          'next': 'url?limit=10&offset=30',
          'previous': 'url?limit=10&offset=10',
          'results': [
            {
              'id': 101,
              'student': 2,
              'student_id': 'STU001',
              'student_name': 'Dara Pich',
              'session': 15,
              'class_room_name': 'CS-101',
              'status': 'present',
              'method': 'qr',
              'checked_in_at': '2026-09-24T08:05:00Z',
              'is_deleted': false,
            }
          ]
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = StudentRepositoryImpl(dio);
      final history = await repo.getAttendanceHistory(
        status: 'present',
        limit: 10,
        offset: 20,
      );

      expect(history.count, 45);
      expect(history.results.length, 1);
      expect(history.results.first.status, 'present');
    });

    test('checkinQr sends token and parses CheckinResponse', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/attendance/checkin/qr/'));
        final data = options.data as Map<String, dynamic>;
        expect(data['qr_token'], 'dyn_session_99');

        final jsonResp = {
          'message': 'Successfully checked in (present).',
          'status': 'present',
          'record': {
            'id': 50,
            'student_name': 'Dara Pich',
            'status': 'present',
          }
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = StudentRepositoryImpl(dio);
      final checkin = await repo.checkinQr('dyn_session_99');

      expect(checkin.success, true);
      expect(checkin.message, contains('Successfully checked in'));
      expect(checkin.record?['id'], 50);
    });

    test('getAlerts parses list of StudentAlertItem', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/alerts/mine/'));
        final jsonResp = [
          {
            'id': 4,
            'session': 12,
            'session_name': 'Mathematics 201',
            'session_date': '2026-09-23',
            'channel': 'telegram',
            'status': 'sent',
            'sent_at': '2026-09-23T10:00:00Z',
            'error_message': '',
          }
        ];
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = StudentRepositoryImpl(dio);
      final alerts = await repo.getAlerts();

      expect(alerts.length, 1);
      expect(alerts.first.sessionName, 'Mathematics 201');
      expect(alerts.first.channel, 'telegram');
    });
  });

  group('TeacherRepository', () {
    test('getTodayClasses returns sessions', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/teacher/classes/today/'));
        final jsonResp = [
          {
            'id': 1,
            'class_room': {'id': 1, 'name': 'Computer Science 101'},
            'date': '2026-09-24',
            'start_time': '08:00:00',
            'end_time': '10:00:00',
            'qr_token': 'dyn_1_abc',
            'is_ended': false,
            'is_qr_valid': true,
          }
        ];
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = TeacherRepositoryImpl(dio);
      final classes = await repo.getTodayClasses();

      expect(classes.length, 1);
      expect(classes.first.id, 1);
      expect(classes.first.classRoomName, 'Computer Science 101');
    });

    test('createSession posts CreateSessionRequest and returns TeacherClassSession', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/teacher/sessions/'));
        expect(options.method, 'POST');
        final data = options.data as Map<String, dynamic>;
        expect(data['class_room'], 1);
        expect(data['date'], '2026-09-24');
        expect(data['start_time'], '08:00');

        final jsonResp = {
          'id': 99,
          'class_room': {'id': 1, 'name': 'Computer Science 101'},
          'date': '2026-09-24',
          'start_time': '08:00:00',
          'end_time': '10:00:00',
          'is_ended': false,
          'is_qr_valid': true,
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = TeacherRepositoryImpl(dio);
      final session = await repo.createSession(
        CreateSessionRequest(
          classRoom: 1,
          date: '2026-09-24',
          startTime: '08:00',
          endTime: '10:00',
        ),
      );

      expect(session.id, 99);
      expect(session.classRoomName, 'Computer Science 101');
    });

    test('getSessionRoster parses SessionRosterResponse', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/teacher/sessions/10/roster/'));
        final jsonResp = {
          'session_id': 10,
          'class_room': 'Computer Science 101',
          'roster': [
            {
              'student_pk': 2,
              'student_id': 'STU001',
              'student_name': 'Dara Pich',
              'attendance_status': 'present',
              'method': 'qr',
              'record_id': 45,
            }
          ],
          'summary': {
            'present': 1,
            'late': 0,
            'absent': 0,
            'unmarked': 0,
            'total': 1,
          }
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = TeacherRepositoryImpl(dio);
      final roster = await repo.getSessionRoster(10);

      expect(roster.sessionId, 10);
      expect(roster.roster.length, 1);
      expect(roster.roster.first.studentName, 'Dara Pich');
      expect(roster.summary?.present, 1);
    });

    test('getDynamicQr returns DynamicQrData', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/teacher/sessions/10/qr/dynamic/'));
        final jsonResp = {
          'session_id': 10,
          'token': 'dyn_10_rot123',
          'interval_seconds': 20,
          'expires_in_seconds': 18,
          'class_room': 'CS-101',
          'date': '2026-09-24',
          'start_time': '08:00',
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = TeacherRepositoryImpl(dio);
      final qr = await repo.getDynamicQr(10);

      expect(qr.sessionId, 10);
      expect(qr.token, 'dyn_10_rot123');
      expect(qr.intervalSeconds, 20);
    });

    test('overrideAttendance sends PATCH', () async {
      final dio = Dio();
      var patched = false;
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/teacher/attendance/55/'));
        expect(options.method, 'PATCH');
        expect(options.data['status'], 'late');
        patched = true;

        return ResponseBody.fromString(
          jsonEncode({'message': 'Attendance updated.'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = TeacherRepositoryImpl(dio);
      await repo.overrideAttendance(recordId: 55, status: 'late');
      expect(patched, true);
    });

    test('submitBulkAttendance sends batch records and parses BulkAttendanceResponse', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/teacher/sessions/10/attendance/bulk/'));
        expect(options.method, 'POST');
        final data = options.data as Map<String, dynamic>;
        final records = data['records'] as List;
        expect(records.length, 2);

        final jsonResp = {
          'message': 'Bulk attendance updated.',
          'updated_count': 2,
          'errors': [],
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = TeacherRepositoryImpl(dio);
      final res = await repo.submitBulkAttendance(
        sessionId: 10,
        records: [
          BulkAttendanceItem(studentId: 'STU001', status: 'present'),
          BulkAttendanceItem(studentId: 'STU002', status: 'absent'),
        ],
      );

      expect(res.updatedCount, 2);
      expect(res.message, contains('Bulk attendance updated'));
    });

    test('exportCsv returns raw CSV string', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/reports/class/1/export-csv/'));
        return ResponseBody.fromString(
          'Student ID,Name,Status\nSTU001,Dara Pich,present\n',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/csv'],
          },
        );
      });

      final repo = TeacherRepositoryImpl(dio);
      final csv = await repo.exportCsv(1);

      expect(csv, contains('Student ID,Name,Status'));
      expect(csv, contains('STU001,Dara Pich,present'));
    });
  });

  group('SystemRepository', () {
    test('checkHealth returns HealthStatus', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        expect(options.path, contains('/health/'));
        final jsonResp = {
          'status': 'healthy',
          'database': 'connected',
          'face_engine': 'available',
          'active_sessions': 2,
          'timestamp': '2026-09-24T08:00:00Z',
        };
        return ResponseBody.fromString(
          jsonEncode(jsonResp),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = SystemRepositoryImpl(dio);
      final health = await repo.checkHealth();

      expect(health.isHealthy, true);
      expect(health.database, 'connected');
      expect(health.faceEngine, 'available');
      expect(health.activeSessions, 2);
    });
  });

  group('AttendanceService delegation', () {
    test('AttendanceService delegates to TeacherRepository', () async {
      final dio = Dio();
      var called = false;
      dio.httpClientAdapter = MockDioAdapter((options) async {
        if (options.path.contains('/end/')) {
          called = true;
          return ResponseBody.fromString(
            jsonEncode({'message': 'Session ended'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 200);
      });

      final teacherRepo = TeacherRepositoryImpl(dio);
      final service = AttendanceService(teacherRepo);

      await service.endSession(10);
      expect(called, true);
    });
  });
}
