import '../core/models/child.dart';
import '../core/models/json.dart';
import '../core/models/page.dart';
import '../core/models/pickup.dart';
import '../core/network/api_client.dart';

/// The guardian app: my children and what I can do for them.
class GuardianRepository {
  GuardianRepository(this._api);

  final ApiClient _api;

  Future<List<Ward>> wards() async =>
      asList((await _api.get('/v1/me/wards'))['data'], Ward.fromJson);

  Future<Ward> ward(int id) async =>
      Ward.fromJson((await _api.get('/v1/me/wards/$id'))['data'] as Json);

  Future<PageOf<Attendance>> attendance(int childId, {int page = 1}) async =>
      PageOf.fromJson(
        await _api.get(
          '/v1/me/wards/$childId/attendance',
          query: {'page': page},
        ),
        Attendance.fromJson,
      );

  Future<Ward> updateNotifications(
    int childId, {
    bool? push,
    bool? sms,
  }) async => Ward.fromJson(
    (await _api.patch(
          '/v1/me/wards/$childId/notifications',
          data: {'push': ?push, 'sms': ?sms},
        ))['data']
        as Json,
  );

  Future<PhotoConsent> photoConsent(int childId) async => PhotoConsent.fromJson(
    (await _api.get('/v1/me/wards/$childId/photo-consent'))['data'] as Json,
  );

  Future<PhotoConsent> updatePhotoConsent(
    int childId, {
    bool? wall,
    bool? groupPhotos,
  }) async => PhotoConsent.fromJson(
    (await _api.put(
          '/v1/me/wards/$childId/photo-consent',
          data: {'wall': ?wall, 'group_photos': ?groupPhotos},
        ))['data']
        as Json,
  );

  Future<PickupCode> pickupCode() async => PickupCode.fromJson(
    (await _api.get('/v1/me/pickup-code'))['data'] as Json,
  );

  Future<List<PickupPass>> passes(int childId) async => asList(
    (await _api.get('/v1/me/wards/$childId/pickup-passes'))['data'],
    PickupPass.fromJson,
  );

  /// Returns the pass and its one-time code (shown once).
  Future<(PickupPass, String)> issuePass(
    int childId, {
    required String name,
    required String phone,
    required DateTime validUntil,
    String? note,
  }) async {
    final json = await _api.post(
      '/v1/me/wards/$childId/pickup-passes',
      data: {
        'name': name,
        'phone': phone,
        'valid_until': validUntil.toUtc().toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return (PickupPass.fromJson(json['data'] as Json), json['code'] as String);
  }

  Future<PickupPass> revokePass(int passId) async => PickupPass.fromJson(
    (await _api.delete('/v1/me/pickup-passes/$passId'))['data'] as Json,
  );
}
