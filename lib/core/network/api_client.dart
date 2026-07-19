import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
      ),
    );
  }

  final Dio dio;
}
