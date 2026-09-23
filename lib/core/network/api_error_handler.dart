import 'package:dio/dio.dart';

/// Maps HTTP errors and Dio exceptions to user-friendly messages
/// following Section 5 HTTP Status Code & Error Handling Matrix from mobile_api_guide.md
class ApiErrorHandler {
  static String getMessage(dynamic error) {
    if (error is! DioException) {
      return error?.toString() ?? 'An unexpected error occurred.';
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    // Check if the backend sent a specific detail or error message in JSON
    if (data is Map<String, dynamic>) {
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
        return 'Check-in is restricted to the authorized campus Wi-Fi network.';
      case 404:
        return 'The requested resource or session was not found.';
      case 429:
        return 'Too many requests. Please wait a few seconds before trying again.';
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
