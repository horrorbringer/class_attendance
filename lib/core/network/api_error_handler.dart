import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ApiError {
  final String title;
  final String message;
  final String? code;
  final IconData icon;
  final Color color;

  ApiError({
    required this.title,
    required this.message,
    this.code,
    required this.icon,
    required this.color,
  });
}

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

  static ApiError parse(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return ApiError(
          title: "Network Error",
          message: "Unable to reach classroom server. Please check your Wi-Fi.",
          code: "NETWORK_ERROR",
          icon: Icons.wifi_off_rounded,
          color: Colors.orange,
        );
      }
      final data = error.response?.data;
      if (data is Map) {
        final code = data['code']?.toString();
        final message = (data['error'] ?? data['detail'] ?? "An error occurred").toString();
        switch (code) {
          case 'DEVICE_REUSE_BLOCKED':
            return ApiError(
              title: "Device Already Used",
              message: "This phone was already used to check in another student for this session.",
              code: code,
              icon: Icons.phonelink_lock_rounded,
              color: Colors.redAccent,
            );
          case 'FACE_IDENTITY_MISMATCH':
            return ApiError(
              title: "Identity Mismatch",
              message: message,
              code: code,
              icon: Icons.face_retouching_off_rounded,
              color: Colors.redAccent,
            );
          case 'TEACHER_LOCKED':
            return ApiError(
              title: "Teacher Locked",
              message: message,
              code: code,
              icon: Icons.lock_clock_rounded,
              color: Colors.amber.shade800,
            );
          case 'IMPOSSIBLE_TRAVEL':
            return ApiError(
              title: "Impossible Check-in",
              message: message,
              code: code,
              icon: Icons.warning_amber_rounded,
              color: Colors.orange.shade800,
            );
          case 'QR_EXPIRED':
            return ApiError(
              title: "Code Expired",
              message: "Please scan the refreshed QR code on the teacher's screen.",
              code: code,
              icon: Icons.timer_off_rounded,
              color: Colors.orange,
            );
          case 'SESSION_ENDED':
          case 'SESSION_EXPIRED':
            return ApiError(
              title: "Class Session Closed",
              message: "This session has ended and is no longer accepting check-ins.",
              code: code,
              icon: Icons.event_busy_rounded,
              color: Colors.grey.shade700,
            );
          case 'NOT_ENROLLED':
            return ApiError(
              title: "Wrong Classroom",
              message: "You are not enrolled in this classroom.",
              code: code,
              icon: Icons.person_off_rounded,
              color: Colors.red,
            );
          case 'CLASSROOM_OVERLAP_CONFLICT':
            return ApiError(
              title: "Classroom Conflict",
              message: message.isNotEmpty && message != "An error occurred"
                  ? message
                  : "Another active class session is already scheduled in this room during this time.",
              code: code,
              icon: Icons.meeting_room_outlined,
              color: Colors.deepOrange,
            );
          case 'TEACHER_SCHEDULE_CONFLICT':
            return ApiError(
              title: "Schedule Conflict",
              message: message.isNotEmpty && message != "An error occurred"
                  ? message
                  : "You are already scheduled in another classroom during this time window.",
              code: code,
              icon: Icons.event_busy_rounded,
              color: Colors.deepOrange,
            );
          case 'INVALID_TIME_RANGE':
            return ApiError(
              title: "Invalid Class Time",
              message: message.isNotEmpty && message != "An error occurred"
                  ? message
                  : "Session end time must be after the start time.",
              code: code,
              icon: Icons.schedule_rounded,
              color: Colors.orange,
            );
          case 'INVALID_QR':
            return ApiError(
              title: "Invalid QR Code",
              message: "Invalid QR code. Please scan the official classroom QR.",
              code: code,
              icon: Icons.qr_code_2_rounded,
              color: Colors.orange,
            );
          case 'REOPEN_WINDOW_EXPIRED':
            return ApiError(
              title: "Reopen Window Expired",
              message: "Cannot reopen a session that ended more than 30 minutes ago.",
              code: code,
              icon: Icons.timer_off_rounded,
              color: Colors.grey.shade700,
            );
          case 'STUDENT_INACTIVE':
            return ApiError(
              title: "Account Inactive",
              message: "Your student account is inactive or suspended. Please contact administration.",
              code: code,
              icon: Icons.person_off_rounded,
              color: Colors.redAccent,
            );
          case 'UNAUTHORIZED':
            return ApiError(
              title: "Unauthorized Access",
              message: "You do not have permission to perform this action.",
              code: code,
              icon: Icons.gpp_bad_rounded,
              color: Colors.red,
            );
          default:
            return ApiError(
              title: "Check-in Notice",
              message: message,
              code: code,
              icon: Icons.info_outline_rounded,
              color: Colors.blueAccent,
            );
        }
      }

      if (error.response?.statusCode == 403) {
        return ApiError(
          title: "Restricted Network",
          message: "Attendance check-in is restricted to the authorized campus Wi-Fi network.",
          code: "WIFI_RESTRICTED",
          icon: Icons.wifi_off_rounded,
          color: Colors.orange,
        );
      }
    }

    return ApiError(
      title: "Unexpected Error",
      message: error?.toString() ?? "An unexpected error occurred.",
      icon: Icons.error_outline_rounded,
      color: Colors.redAccent,
    );
  }

  static void showErrorDialog(BuildContext context, dynamic error) {
    final parsed = parse(error);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: CircleAvatar(
          backgroundColor: parsed.color.withValues(alpha: 0.15),
          radius: 28,
          child: Icon(parsed.icon, color: parsed.color, size: 30),
        ),
        title: Text(parsed.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(parsed.message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  static String getMessage(dynamic error) {
    return parse(error).message;
  }

  static String getErrorMessage(dynamic error) {
    return getMessage(error);
  }
}
