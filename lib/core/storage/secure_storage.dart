import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'user_role';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _fullNameKey = 'user_full_name';
  static const _emailKey = 'user_email';

  static Future<void> saveSession({
    required String token,
    required String role,
    required int userId,
    required String username,
    String? fullName,
    String? email,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
    if (fullName != null) {
      await prefs.setString(_fullNameKey, fullName);
    }
    if (email != null && email.isNotEmpty) {
      await prefs.setString(_emailKey, email);
    }
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fullNameKey);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static const _onboardingSeenKey = 'has_seen_onboarding';

  // Biometric storage keys
  static const _biometricStudentEnabledKey = 'biometric_student_enabled';
  static const _biometricTeacherEnabledKey = 'biometric_teacher_enabled';
  static const _biometricStudentUserKey = 'biometric_student_username';
  static const _biometricStudentPassKey = 'biometric_student_password';
  static const _biometricTeacherUserKey = 'biometric_teacher_username';
  static const _biometricTeacherPassKey = 'biometric_teacher_password';
  static const _lastUserKey = 'last_login_username_';
  static const _lastPassKey = 'last_login_password_';

  static Future<bool> isBiometricEnabled([String role = 'student']) async {
    final prefs = await SharedPreferences.getInstance();
    final key = role == 'teacher' ? _biometricTeacherEnabledKey : _biometricStudentEnabledKey;
    return prefs.getBool(key) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled, [String role = 'student']) async {
    final prefs = await SharedPreferences.getInstance();
    final key = role == 'teacher' ? _biometricTeacherEnabledKey : _biometricStudentEnabledKey;
    await prefs.setBool(key, enabled);
    if (!enabled) {
      await clearBiometricCredentials(role);
    }
  }

  static Future<void> saveBiometricCredentials({
    required String username,
    required String password,
    String role = 'student',
  }) async {
    final userKey = role == 'teacher' ? _biometricTeacherUserKey : _biometricStudentUserKey;
    final passKey = role == 'teacher' ? _biometricTeacherPassKey : _biometricStudentPassKey;
    await _storage.write(key: userKey, value: username);
    await _storage.write(key: passKey, value: password);
  }

  static Future<Map<String, String>?> getBiometricCredentials([String role = 'student']) async {
    final userKey = role == 'teacher' ? _biometricTeacherUserKey : _biometricStudentUserKey;
    final passKey = role == 'teacher' ? _biometricTeacherPassKey : _biometricStudentPassKey;
    final username = await _storage.read(key: userKey);
    final password = await _storage.read(key: passKey);
    if (username != null && password != null && username.isNotEmpty && password.isNotEmpty) {
      return {'username': username, 'password': password};
    }
    return null;
  }

  static Future<void> clearBiometricCredentials([String role = 'student']) async {
    final userKey = role == 'teacher' ? _biometricTeacherUserKey : _biometricStudentUserKey;
    final passKey = role == 'teacher' ? _biometricTeacherPassKey : _biometricStudentPassKey;
    await _storage.delete(key: userKey);
    await _storage.delete(key: passKey);
  }

  static Future<void> saveLastKnownCredentials({
    required String username,
    required String password,
    required String role,
  }) async {
    await _storage.write(key: '$_lastUserKey$role', value: username);
    await _storage.write(key: '$_lastPassKey$role', value: password);
  }

  static Future<Map<String, String>?> getLastKnownCredentials(String role) async {
    final username = await _storage.read(key: '$_lastUserKey$role');
    final password = await _storage.read(key: '$_lastPassKey$role');
    if (username != null && password != null && username.isNotEmpty && password.isNotEmpty) {
      return {'username': username, 'password': password};
    }
    return null;
  }

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  static Future<void> setOnboardingSeen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, value);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_fullNameKey);
  }
}
