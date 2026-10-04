import 'package:flutter/foundation.dart';

/// Build-time configuration:
///   flutter run --dart-define=API_BASE_URL=https://app.bahga.example/api
class Env {
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The API root (no trailing slash). Defaults to a local Laravel server
  /// (10.0.2.2 is the host machine from the Android emulator).
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (kIsWeb) return 'http://localhost:8000/api';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000/api'
        : 'http://localhost:8000/api';
  }

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
}
