import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

ApiException mapApiException(Object error) {
  if (error is ApiException) return error;

  if (error is DioException) {
    final response = error.response;
    final data = response?.data;
    String? detail;

    if (data is Map<String, dynamic>) {
      final rawDetail = data['detail'] ?? data['message'];
      if (rawDetail is String) detail = rawDetail;
      if (rawDetail is List) {
        detail = rawDetail
            .map((item) => item is Map ? item['msg']?.toString() : item.toString())
            .whereType<String>()
            .join('\n');
      }
    }

    if (detail != null && detail.trim().isNotEmpty) {
      return ApiException(detail, statusCode: response?.statusCode);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Kết nối đến máy chủ quá thời gian.');
      case DioExceptionType.connectionError:
        return const ApiException(
          'Không kết nối được backend. Hãy kiểm tra Uvicorn và địa chỉ API.',
        );
      default:
        return ApiException(
          error.message ?? 'Đã xảy ra lỗi khi gọi API.',
          statusCode: response?.statusCode,
        );
    }
  }

  return ApiException(error.toString());
}
