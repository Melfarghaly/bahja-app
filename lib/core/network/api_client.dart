import 'package:dio/dio.dart';

import '../config/env.dart';
import '../models/json.dart';
import '../storage/session_store.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio for the Bahga API:
/// - adds `Authorization`, `X-Tenant-Id`, `Accept-Language`;
/// - turns every failure into an [ApiException];
/// - reports an expired session (401) so the app can sign out.
class ApiClient {
  ApiClient({
    required this.session,
    Dio? dio,
    String? baseUrl,
    this.onUnauthenticated,
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? Env.apiBaseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               headers: {'Accept': 'application/json'},
             ),
           ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = session.token;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          final tenantId = session.tenantId;
          if (tenantId != null && options.extra['tenant'] != false) {
            options.headers['X-Tenant-Id'] = '$tenantId';
          }
          options.headers['Accept-Language'] = session.locale;
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final SessionStore session;

  /// Called once per 401 on an authenticated request.
  void Function()? onUnauthenticated;

  Future<Json> get(
    String path, {
    Map<String, dynamic>? query,
    bool tenant = true,
  }) => _send(
    () => dio.get<dynamic>(
      path,
      queryParameters: _clean(query),
      options: _options(tenant),
    ),
  );

  Future<Json> post(String path, {Object? data, bool tenant = true}) => _send(
    () => dio.post<dynamic>(path, data: data, options: _options(tenant)),
  );

  Future<Json> put(String path, {Object? data}) =>
      _send(() => dio.put<dynamic>(path, data: data));

  Future<Json> patch(String path, {Object? data, bool tenant = true}) => _send(
    () => dio.patch<dynamic>(path, data: data, options: _options(tenant)),
  );

  Future<Json> delete(String path, {Object? data, bool tenant = true}) => _send(
    () => dio.delete<dynamic>(path, data: data, options: _options(tenant)),
  );

  Options _options(bool tenant) => Options(extra: {'tenant': tenant});

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) =>
      query == null ? null : (Map.of(query)..removeWhere((_, v) => v == null));

  Future<Json> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return const {}; // 204 No Content
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (error.isUnauthenticated && session.token != null) {
        onUnauthenticated?.call();
      }
      throw error;
    }
  }
}
