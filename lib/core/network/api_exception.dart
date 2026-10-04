import 'package:dio/dio.dart';

/// The API's unified error: `{message, code, errors}` (message already in
/// the request language). Network failures map to `code: network_error`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.code,
    this.statusCode,
    this.fieldErrors = const {},
  });

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;

    if (data is Map<String, dynamic> && data['message'] is String) {
      final errors = <String, List<String>>{};
      if (data['errors'] is Map) {
        (data['errors'] as Map).forEach((key, value) {
          if (value is List) {
            errors[key.toString()] = value.map((e) => e.toString()).toList();
          }
        });
      }
      return ApiException(
        message: data['message'] as String,
        code: data['code'] as String? ?? 'error',
        statusCode: response?.statusCode,
        fieldErrors: errors,
      );
    }

    if (response == null) {
      return const ApiException(
        message: 'تعذّر الاتصال بالخادم. تحقّق من الإنترنت ثم أعد المحاولة.',
        code: 'network_error',
      );
    }

    return ApiException(
      message: 'حدث خطأ غير متوقع (${response.statusCode}).',
      code: 'error',
      statusCode: response.statusCode,
    );
  }

  final String message;
  final String code;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthenticated => statusCode == 401;
  bool get isValidation => statusCode == 422;

  /// The first message for a field (form validation), if any.
  String? fieldError(String field) => fieldErrors[field]?.first;

  @override
  String toString() => message;
}
