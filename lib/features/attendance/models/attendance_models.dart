import '../../auth/models/auth_models.dart';

class StudentScheduleSession {
  final int id;
  final String classRoom;
  final String date;
  final String startTime;
  final String endTime;
  final bool isQrActive;
  final bool isCheckedIn;
  final String? myStatus;
  final String? myMethod;
  final String? checkedInAt;

  StudentScheduleSession({
    required this.id,
    required this.classRoom,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isQrActive,
    required this.isCheckedIn,
    this.myStatus,
    this.myMethod,
    this.checkedInAt,
  });

  factory StudentScheduleSession.fromJson(Map<String, dynamic> json) {
    return StudentScheduleSession(
      id: json['id'] as int? ?? 0,
      classRoom: json['class_room']?.toString() ?? '',
      date: json['date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      isQrActive: json['is_qr_active'] as bool? ?? false,
      isCheckedIn: json['is_checked_in'] as bool? ?? false,
      myStatus: json['my_status'] as String?,
      myMethod: json['my_method'] as String?,
      checkedInAt: json['checked_in_at'] as String?,
    );
  }
}

class AttendanceRecord {
  final int id;
  final int? student;
  final String studentId;
  final String studentName;
  final int? session;
  final String classRoomName;
  final String status; // 'present', 'late', 'absent'
  final String method; // 'qr', 'face', 'manual'
  final String checkedInAt;
  final double? confidenceScore;
  final bool isDeleted;

  AttendanceRecord({
    required this.id,
    this.student,
    required this.studentId,
    required this.studentName,
    this.session,
    required this.classRoomName,
    required this.status,
    required this.method,
    required this.checkedInAt,
    this.confidenceScore,
    required this.isDeleted,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int? ?? 0,
      student: json['student'] as int?,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      session: json['session'] as int?,
      classRoomName: json['class_room_name'] as String? ?? '',
      status: json['status'] as String? ?? 'present',
      method: json['method'] as String? ?? 'qr',
      checkedInAt: json['checked_in_at'] as String? ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }
}

class TeacherClassSession {
  final int id;
  final ClassRoom? classRoom;
  final String classRoomName;
  final String date;
  final String startTime;
  final String endTime;
  final String? qrToken;
  final String? qrTokenExpiresAt;
  final String? endedAt;
  final bool isEnded;
  final bool isQrValid;

  TeacherClassSession({
    required this.id,
    this.classRoom,
    required this.classRoomName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.qrToken,
    this.qrTokenExpiresAt,
    this.endedAt,
    required this.isEnded,
    required this.isQrValid,
  });

  factory TeacherClassSession.fromJson(Map<String, dynamic> json) {
    String crName = '';
    ClassRoom? crObj;
    if (json['class_room'] is Map) {
      crObj = ClassRoom.fromJson(json['class_room'] as Map<String, dynamic>);
      crName = crObj.name;
    } else if (json['class_room'] != null) {
      crName = json['class_room'].toString();
    }

    return TeacherClassSession(
      id: json['id'] as int? ?? 0,
      classRoom: crObj,
      classRoomName: crName,
      date: json['date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      qrToken: json['qr_token'] as String?,
      qrTokenExpiresAt: json['qr_token_expires_at'] as String?,
      endedAt: json['ended_at'] as String?,
      isEnded: json['is_ended'] as bool? ?? false,
      isQrValid: json['is_qr_valid'] as bool? ?? false,
    );
  }
}

class RosterStudent {
  final int studentPk;
  final String studentId;
  final String studentName;
  final bool isActive;
  final String guardianContact;
  String attendanceStatus; // 'present', 'late', 'absent', 'unmarked'
  String? method;
  String? checkedInAt;
  int? recordId;
  bool isDeleted;

  RosterStudent({
    required this.studentPk,
    required this.studentId,
    required this.studentName,
    required this.isActive,
    required this.guardianContact,
    required this.attendanceStatus,
    this.method,
    this.checkedInAt,
    this.recordId,
    required this.isDeleted,
  });

  factory RosterStudent.fromJson(Map<String, dynamic> json) {
    return RosterStudent(
      studentPk: json['student_pk'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      guardianContact: json['guardian_contact'] as String? ?? '',
      attendanceStatus: json['attendance_status'] as String? ?? 'unmarked',
      method: json['method'] as String?,
      checkedInAt: json['checked_in_at'] as String?,
      recordId: json['record_id'] as int?,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }
}

class RosterSummary {
  final int present;
  final int late;
  final int absent;
  final int unmarked;
  final int total;

  RosterSummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.unmarked,
    required this.total,
  });

  factory RosterSummary.fromJson(Map<String, dynamic> json) {
    return RosterSummary(
      present: json['present'] as int? ?? 0,
      late: json['late'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      unmarked: json['unmarked'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }
}

class LiveFeedCheckin {
  final int recordId;
  final String studentId;
  final String studentName;
  final String status;
  final String method;
  final String? checkedInAt;

  LiveFeedCheckin({
    required this.recordId,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.method,
    this.checkedInAt,
  });

  factory LiveFeedCheckin.fromJson(Map<String, dynamic> json) {
    return LiveFeedCheckin(
      recordId: json['record_id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      status: json['status'] as String? ?? 'present',
      method: json['method'] as String? ?? 'qr',
      checkedInAt: json['checked_in_at'] as String?,
    );
  }
}

class LiveFeedData {
  final int sessionId;
  final String classRoom;
  final String date;
  final bool isEnded;
  final int totalEnrolled;
  final int checkedInCount;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int unmarkedCount;
  final List<LiveFeedCheckin> recentCheckins;

  LiveFeedData({
    required this.sessionId,
    required this.classRoom,
    required this.date,
    required this.isEnded,
    required this.totalEnrolled,
    required this.checkedInCount,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.unmarkedCount,
    required this.recentCheckins,
  });

  factory LiveFeedData.fromJson(Map<String, dynamic> json) {
    final list = json['recent_checkins'] as List<dynamic>? ?? [];
    return LiveFeedData(
      sessionId: json['session_id'] as int? ?? 0,
      classRoom: json['class_room'] as String? ?? '',
      date: json['date'] as String? ?? '',
      isEnded: json['is_ended'] as bool? ?? false,
      totalEnrolled: json['total_enrolled'] as int? ?? 0,
      checkedInCount: json['checked_in_count'] as int? ?? 0,
      presentCount: json['present_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      unmarkedCount: json['unmarked_count'] as int? ?? 0,
      recentCheckins: list.map((e) => LiveFeedCheckin.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class DynamicQrData {
  final int sessionId;
  final String token;
  final int intervalSeconds;
  final int expiresInSeconds;
  final String classRoom;
  final String date;
  final String startTime;

  DynamicQrData({
    required this.sessionId,
    required this.token,
    required this.intervalSeconds,
    required this.expiresInSeconds,
    required this.classRoom,
    required this.date,
    required this.startTime,
  });

  factory DynamicQrData.fromJson(Map<String, dynamic> json) {
    return DynamicQrData(
      sessionId: json['session_id'] as int? ?? 0,
      token: json['token'] as String? ?? '',
      intervalSeconds: json['interval_seconds'] as int? ?? 20,
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 20,
      classRoom: json['class_room'] as String? ?? '',
      date: json['date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
    );
  }
}
