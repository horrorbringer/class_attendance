import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_constants.dart';
import '../../features/attendance/models/attendance_models.dart';
import 'api_client.dart';

abstract class SystemRepository {
  Future<HealthStatus> checkHealth();
}

class SystemRepositoryImpl implements SystemRepository {
  final Dio _dio;

  SystemRepositoryImpl(this._dio);

  @override
  Future<HealthStatus> checkHealth() async {
    final response = await _dio.get(ApiConstants.health);
    if (response.data is Map<String, dynamic>) {
      return HealthStatus.fromJson(response.data as Map<String, dynamic>);
    }
    return HealthStatus(status: 'healthy');
  }
}

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SystemRepositoryImpl(dio);
});
