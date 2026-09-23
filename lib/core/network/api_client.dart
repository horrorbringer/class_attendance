import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_constants.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      onUnauthorized: () {
        // Clear stored session — the AuthGate in main.dart watches authProvider,
        // so when restoreSession() runs next and finds no token, it routes to LoginScreen.
        StorageService.clearSession();
        // Trigger auth state re-evaluation by invalidating via the container
        _onUnauthorizedCallback?.call();
      },
    ),
  );

  return dio;
});

/// Global callback set by AuthNotifier to force logout on 401.
VoidCallback? _onUnauthorizedCallback;

/// Register a callback to be called on 401 Unauthorized.
/// AuthNotifier calls this during build() to wire itself up.
void registerUnauthorizedCallback(VoidCallback callback) {
  _onUnauthorizedCallback = callback;
}
