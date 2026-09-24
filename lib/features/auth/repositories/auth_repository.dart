import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';

abstract class AuthRepository {
  Future<UserSession> login(String username, String password);
  Future<void> logout();
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    String? confirmPassword,
  });
  Future<StudentProfile> getStudentProfile();
}

class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;

  AuthRepositoryImpl(this._dio);

  @override
  Future<UserSession> login(String username, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {
        'username': username.trim(),
        'password': password.trim(),
      },
    );

    final data = response.data as Map<String, dynamic>;
    return UserSession.fromJson(data);
  }

  @override
  Future<void> logout() async {
    await _dio.post(ApiConstants.logout);
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    String? confirmPassword,
  }) async {
    final payload = <String, dynamic>{
      'old_password': oldPassword,
      'new_password': newPassword,
    };
    if (confirmPassword != null && confirmPassword.isNotEmpty) {
      payload['confirm_password'] = confirmPassword;
    }

    await _dio.post(
      ApiConstants.changePassword,
      data: payload,
    );
  }

  @override
  Future<StudentProfile> getStudentProfile() async {
    final response = await _dio.get(ApiConstants.studentProfile);
    return StudentProfile.fromJson(response.data as Map<String, dynamic>);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepositoryImpl(dio);
});
