import '../core/models/json.dart';
import '../core/models/user.dart';
import '../core/network/api_client.dart';

class OtpRequest {
  const OtpRequest({
    required this.message,
    required this.expiresIn,
    required this.resendAfter,
  });

  final String message;
  final int expiresIn;
  final int resendAfter;
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  static const deviceName = 'bahga-app';

  /// Email or phone + password → token.
  Future<String> login(String login, String password) async {
    final json = await _api.post(
      '/v1/auth/tokens',
      data: {
        'login': login.trim(),
        'password': password,
        'device_name': deviceName,
      },
      tenant: false,
    );
    return json['token'] as String;
  }

  Future<OtpRequest> requestOtp(String phone) async {
    final json = await _api.post(
      '/v1/auth/otp',
      data: {'phone': phone.trim()},
      tenant: false,
    );
    return OtpRequest(
      message: json['message'] as String? ?? '',
      expiresIn: asInt(json['expires_in']) ?? 300,
      resendAfter: asInt(json['resend_after']) ?? 60,
    );
  }

  Future<String> verifyOtp(String phone, String code) async {
    final json = await _api.post(
      '/v1/auth/otp/verify',
      data: {
        'phone': phone.trim(),
        'code': code.trim(),
        'device_name': deviceName,
      },
      tenant: false,
    );
    return json['token'] as String;
  }

  Future<AppUser> me() async => AppUser.fromJson(
    (await _api.get('/v1/me', tenant: false))['data'] as Json,
  );

  Future<AppUser> updateProfile({String? name, String? email}) async {
    final json = await _api.patch(
      '/v1/me',
      data: {'name': ?name, 'email': ?email},
      tenant: false,
    );
    return AppUser.fromJson(json['data'] as Json);
  }

  Future<void> logout() =>
      _api.delete('/v1/auth/tokens/current', tenant: false);

  Future<void> registerDevice({
    required String token,
    required String platform,
    required String locale,
    required String appVersion,
  }) => _api.post(
    '/v1/me/devices',
    data: {
      'token': token,
      'platform': platform,
      'locale': locale,
      'app_version': appVersion,
    },
    tenant: false,
  );
}
