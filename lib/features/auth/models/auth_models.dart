class TeacherProfile {
  final int id;
  final String name;
  final String email;

  TeacherProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    return TeacherProfile(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };
}

class ClassRoom {
  final int id;
  final String name;
  final TeacherProfile? teacher;

  ClassRoom({
    required this.id,
    required this.name,
    this.teacher,
  });

  factory ClassRoom.fromJson(Map<String, dynamic> json) {
    return ClassRoom(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      teacher: json['teacher'] != null
          ? TeacherProfile.fromJson(json['teacher'] as Map<String, dynamic>)
          : null,
    );
  }
}

class StudentSummary {
  final int id;
  final String studentId;
  final String name;

  StudentSummary({
    required this.id,
    required this.studentId,
    required this.name,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      id: json['id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class StudentProfile {
  final int id;
  final String studentId;
  final String fullName;
  final String classYear;
  final bool isActive;
  final String guardianContact;
  final ClassRoom? classRoom;
  final int faceEmbeddingsCount;
  final String? consentGivenAt;

  StudentProfile({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.classYear,
    required this.isActive,
    required this.guardianContact,
    this.classRoom,
    required this.faceEmbeddingsCount,
    this.consentGivenAt,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? '',
      classYear: json['class_year'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      guardianContact: json['guardian_contact'] as String? ?? '',
      classRoom: json['class_room'] != null && json['class_room'] is Map
          ? ClassRoom.fromJson(json['class_room'] as Map<String, dynamic>)
          : null,
      faceEmbeddingsCount: json['face_embeddings_count'] as int? ?? 0,
      consentGivenAt: json['consent_given_at'] as String?,
    );
  }
}

class UserSession {
  final String token;
  final int userId;
  final String username;
  final String role; // 'student', 'teacher', 'admin'
  final StudentSummary? student;
  final TeacherProfile? teacher;

  UserSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.role,
    this.student,
    this.teacher,
  });

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher' || role == 'admin';

  String get displayName {
    if (student != null && student!.name.isNotEmpty) return student!.name;
    if (teacher != null && teacher!.name.isNotEmpty) return teacher!.name;
    return username;
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      token: json['token'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      student: json['student'] != null && json['student'] is Map
          ? StudentSummary.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      teacher: json['teacher'] != null && json['teacher'] is Map
          ? TeacherProfile.fromJson(json['teacher'] as Map<String, dynamic>)
          : null,
    );
  }
}
