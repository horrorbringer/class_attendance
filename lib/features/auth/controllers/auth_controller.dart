import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/auth_models.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserSession? session;
  final StudentProfile? studentProfile;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.session,
    this.studentProfile,
  });

  bool get isAuthenticated => session != null && session!.token.isNotEmpty;
  bool get isStudent => session?.isStudent ?? false;
  bool get isTeacher => session?.isTeacher ?? false;

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserSession? session,
    StudentProfile? studentProfile,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      session: clearSession ? null : (session ?? this.session),
      studentProfile: clearSession ? null : (studentProfile ?? this.studentProfile),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late Dio _dio;

  @override
  AuthState build() {
    _dio = ref.watch(dioProvider);

    // Wire up 401 Unauthorized handler so expired tokens
    // trigger a full state reset → AuthGate routes to LoginScreen
    registerUnauthorizedCallback(() {
      if (state.isAuthenticated) {
        debugPrint('[AuthNotifier] 401 detected — forcing logout');
        state = AuthState(isLoading: false);
      }
    });

    Future.microtask(() => restoreSession());
    return AuthState(isLoading: true);
  }

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final token = await StorageService.getToken();
    final role = await StorageService.getRole();
    final userId = await StorageService.getUserId();
    final username = await StorageService.getUsername();
    final fullName = await StorageService.getFullName();

    if (token != null && token.isNotEmpty && role != null && userId != null && username != null) {
      final session = UserSession(
        token: token,
        userId: userId,
        username: username,
        role: role,
        student: role == 'student'
            ? StudentSummary(id: userId, studentId: username, name: fullName ?? username)
            : null,
        teacher: role == 'teacher'
            ? TeacherProfile(id: userId, name: fullName ?? username, email: '')
            : null,
      );

      state = state.copyWith(isLoading: false, session: session);

      if (role == 'student') {
        await fetchStudentProfile();
      }
    } else {
      state = state.copyWith(isLoading: false, clearSession: true);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          'username': username.trim(),
          'password': password.trim(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      final session = UserSession.fromJson(data);

      await StorageService.saveSession(
        token: session.token,
        role: session.role,
        userId: session.userId,
        username: session.username,
        fullName: session.displayName,
      );

      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
      );

      if (session.isStudent) {
        await fetchStudentProfile();
      }

      return true;
    } on DioException catch (e) {
      String msg = 'Login failed. Please check your credentials.';
      if (e.response?.data != null && e.response?.data is Map) {
        final resData = e.response!.data as Map;
        if (resData.containsKey('non_field_errors')) {
          msg = (resData['non_field_errors'] as List).join(' ');
        } else if (resData.containsKey('error')) {
          msg = resData['error'].toString();
        } else if (resData.containsKey('detail')) {
          msg = resData['detail'].toString();
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> fetchStudentProfile() async {
    try {
      final response = await _dio.get(ApiConstants.studentProfile);
      final profile = StudentProfile.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(studentProfile: profile);
    } catch (_) {
      // Profile fetch can fail silently or retry
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      await StorageService.clearSession();
      state = AuthState(isLoading: false);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
