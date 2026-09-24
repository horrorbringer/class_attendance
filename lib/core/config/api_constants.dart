import 'dart:io';

class ApiConstants {
  // Set to true to connect to the live cloud backend, or false for local development
  static const bool useCloudBackend = true;

  // 1. Live Cloud Production Backend Root
  static const String cloudBaseUrl = 'https://student-attendance.vanny.monster/api';

  // 2. Dynamic Base URL Resolution (supports Cloud, Android Emulator, iOS Simulator, LAN IP)
  static String get baseUrl {
    if (useCloudBackend) {
      return cloudBaseUrl;
    }

    // Android Emulator loopback
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8000/api";
    }
    // iOS Simulator loopback
    if (Platform.isIOS) {
      return "http://127.0.0.1:8000/api";
    }
    // Physical Device over Wi-Fi (Change to your LAN IP)
    return "http://192.168.1.100:8000/api";
  }

  // System
  static const String health = '/health/';
  static const String schema = '/schema/';

  // Auth
  static const String login = '/auth/login/';
  static const String logout = '/auth/logout/';
  static const String changePassword = '/auth/change-password/';

  // Student
  static const String studentProfile = '/students/me/';
  static const String studentScheduleToday = '/students/schedule/today/';
  static const String studentAlerts = '/alerts/mine/';
  static const String attendanceHistory = '/attendance/history/';
  static const String checkinQr = '/attendance/checkin/qr/';
  static const String checkinFace = '/attendance/checkin/face/';
  static const String faceEnroll = '/face/enroll/';

  // Teacher
  static const String teacherTodayClasses = '/teacher/classes/today/';
  static const String teacherSessions = '/teacher/sessions/';
  static String sessionRoster(int sessionId) => '/teacher/sessions/$sessionId/roster/';
  static String sessionLiveFeed(int sessionId) => '/teacher/sessions/$sessionId/live-feed/';
  static String sessionDynamicQr(int sessionId) => '/teacher/sessions/$sessionId/qr/dynamic/';
  static String sessionRotateQr(int sessionId) => '/teacher/sessions/$sessionId/qr/';
  static String sessionEnd(int sessionId) => '/teacher/sessions/$sessionId/end/';
  static String sessionReopen(int sessionId) => '/teacher/sessions/$sessionId/reopen/';
  static String sessionCancel(int sessionId) => '/teacher/sessions/$sessionId/cancel/';
  static String teacherCancelSession(int sessionId) => '/teacher/sessions/$sessionId/cancel/';
  static String sessionBulkAttendance(int sessionId) => '/teacher/sessions/$sessionId/attendance/bulk/';
  static String teacherAttendanceOverride(int recordId) => '/teacher/attendance/$recordId/';

  // Reports
  static String classReport(int classId) => '/reports/class/$classId/';
  static String studentReport(int studentId) => '/reports/student/$studentId/';
  static String exportCsv(int classId) => '/reports/class/$classId/export-csv/';
}
