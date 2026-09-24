import 'package:dio/dio.dart';

/// Maps HTTP errors, backend error codes, and Dio exceptions to user-friendly messages
/// following Section 5 HTTP Status Code & Error Handling Matrix from mobile_api_guide.md
class ApiErrorHandler {
  /// Extracts the backend machine-readable error code (e.g. QR_EXPIRED, TEACHER_LOCKED, NOT_ENROLLED)
  static String? getErrorCode(dynamic error) {
    if (error is DioException && error.response?.data is Map) {
      final data = error.response!.data as Map;
      return data['code']?.toString();
    }
    return null;
  }

  static String getMessage(dynamic error) {
    if (error is! DioException) {
      return error?.toString() ?? 'An unexpected error occurred.';
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    // 1. Check if backend provided a specific security/business error code
    if (data is Map) {
      final code = data['code']?.toString();
      if (code != null) {
        switch (code) {
          case 'QR_EXPIRED':
            return 'Code Expired: Please scan the active rotating QR code currently on the teacher\'s screen.';
          case 'TEACHER_LOCKED':
            return data['error']?.toString() ??
                data['message']?.toString() ??
                'Teacher Locked: This attendance record was manually recorded by your teacher and cannot be overwritten.';
          case 'IMPOSSIBLE_TRAVEL':
            return 'Impossible Travel: You checked in to another classroom less than 15 minutes ago.';
          case 'SESSION_EXPIRED':
          case 'SESSION_ENDED':
            return 'Session Closed: This class session has concluded and is no longer accepting check-ins.';
          case 'NOT_ENROLLED':
            return 'Wrong Classroom: You are not enrolled in this course or section.';
          case 'ALREADY_CHECKED_IN':
            return 'Already Checked In: Your attendance was already recorded for this session.';
        }
      }

      // 2. Check if the backend sent a specific detail or error message in JSON
      final detail = data['detail'] ?? data['error'] ?? data['message'];
      if (detail != null && detail.toString().isNotEmpty) {
        return detail.toString();
      }
    }

    switch (statusCode) {
      case 400:
        return 'Invalid request. Please verify your data and retry.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'Attendance check-in is restricted to the authorized campus Wi-Fi network.';
      case 404:
        return 'The requested resource or session was not found.';
      case 409:
        return 'Conflict detected. Please verify your check-in status with your instructor.';
      case 429:
        return 'Too many requests. Please wait 10 seconds before trying again.';
      case 500:
        return 'Internal server error. Please try again later.';
      case 502:
      case 503:
      case 504:
        return 'Server undergoing maintenance. Please try again shortly.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your network connection.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Please check your internet connection.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'A network error occurred. Please try again.';
    }
  }
}
