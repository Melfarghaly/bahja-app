import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the API token, the chosen nursery and the language live between launches.
abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String? token);
  Future<int?> readTenantId();
  Future<void> writeTenantId(int? id);
  Future<String?> readLocale();
  Future<void> writeLocale(String locale);

  /// Cached in memory for the request interceptor (no async per request).
  String? token;
  int? tenantId;
  String locale = 'ar';
}

/// Keychain (iOS) / EncryptedSharedPreferences (Android).
class SecureSessionStore extends SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() async =>
      token = await _storage.read(key: 'token');

  @override
  Future<void> writeToken(String? value) async {
    token = value;
    value == null
        ? await _storage.delete(key: 'token')
        : await _storage.write(key: 'token', value: value);
  }

  @override
  Future<int?> readTenantId() async =>
      tenantId = int.tryParse(await _storage.read(key: 'tenant_id') ?? '');

  @override
  Future<void> writeTenantId(int? id) async {
    tenantId = id;
    id == null
        ? await _storage.delete(key: 'tenant_id')
        : await _storage.write(key: 'tenant_id', value: '$id');
  }

  @override
  Future<String?> readLocale() async {
    final stored = await _storage.read(key: 'locale');
    if (stored != null) locale = stored;
    return stored;
  }

  @override
  Future<void> writeLocale(String value) async {
    locale = value;
    await _storage.write(key: 'locale', value: value);
  }
}

/// For tests.
class MemorySessionStore extends SessionStore {
  MemorySessionStore({String? token, int? tenantId}) {
    this.token = token;
    this.tenantId = tenantId;
  }

  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> writeToken(String? value) async => token = value;
  @override
  Future<int?> readTenantId() async => tenantId;
  @override
  Future<void> writeTenantId(int? id) async => tenantId = id;
  @override
  Future<String?> readLocale() async => locale;
  @override
  Future<void> writeLocale(String value) async => locale = value;
}
