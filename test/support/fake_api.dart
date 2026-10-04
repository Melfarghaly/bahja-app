import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bahja_app/core/network/api_client.dart';
import 'package:bahja_app/core/storage/session_store.dart';
import 'package:dio/dio.dart';

/// Real API responses captured in the backend's Postman collection.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(fixture(name)) as Map<String, dynamic>;

/// Answers requests from a route table ("GET /v1/me" → status + body) and
/// records every request for assertions.
class FakeAdapter implements HttpClientAdapter {
  final Map<String, (int, String)> routes = {};
  final List<RequestOptions> requests = [];

  void on(String method, String path, {int status = 200, String body = '{}'}) =>
      routes['$method $path'] = (status, body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route for ${options.method} ${options.path}',
      );
    }
    return ResponseBody.fromString(
      route.$2,
      route.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient fakeClient(FakeAdapter adapter, SessionStore session) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://bahga.test/api',
      headers: {'Accept': 'application/json'},
    ),
  )..httpClientAdapter = adapter;
  return ApiClient(session: session, dio: dio);
}
