class ApiConstants {
  // Live Production Backend Root
  static const String baseUrl = 'https://student-attendance.vanny.monster/api';

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
  static String sessionBulkAttendance(int sessionId) => '/teacher/sessions/$sessionId/attendance/bulk/';
  static String teacherAttendanceOverride(int recordId) => '/teacher/attendance/$recordId/';

  // Reports
  static String classReport(int classId) => '/reports/class/$classId/';
  static String studentReport(int studentId) => '/reports/student/$studentId/';
}
