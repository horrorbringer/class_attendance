import 'dart:async';
import 'package:dio/dio.dart';

/// Interceptor that automatically retries idempotent requests (GET, HEAD, OPTIONS)
/// on transient network timeouts and 503 Service Unavailable errors with exponential backoff.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.initialDelay = const Duration(milliseconds: 800),
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;

    // Only retry idempotent methods (GET, HEAD, OPTIONS) to avoid duplicate state mutations
    final method = requestOptions.method.toUpperCase();
    final isIdempotent = method == 'GET' || method == 'HEAD' || method == 'OPTIONS';

    if (!isIdempotent) {
      return handler.next(err);
    }

    final isTransient = _isTransientError(err);
    if (!isTransient) {
      return handler.next(err);
    }

    final currentRetry = (requestOptions.extra['retry_count'] as int?) ?? 0;
    if (currentRetry >= maxRetries) {
      return handler.next(err);
    }

    final nextRetry = currentRetry + 1;
    requestOptions.extra['retry_count'] = nextRetry;

    // Exponential backoff: 800ms, 1600ms
    final delay = initialDelay * nextRetry;
    await Future.delayed(delay);

    try {
      final response = await dio.fetch(requestOptions);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (e) {
      return handler.next(err);
    }
  }

  bool _isTransientError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // 503 Service Unavailable / 502 Bad Gateway / 504 Gateway Timeout
    final statusCode = err.response?.statusCode;
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return true;
    }

    return false;
  }
}
