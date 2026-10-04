import '../core/models/attendance_sheet.dart';
import '../core/models/child.dart';
import '../core/models/json.dart';
import '../core/models/page.dart';
import '../core/models/pickup.dart';
import '../core/network/api_client.dart';

/// Teacher / manager: classrooms, children, the daily sheet and the door.
class StaffRepository {
  StaffRepository(this._api);

  final ApiClient _api;

  Future<List<ClassroomRef>> classrooms() async =>
      asList((await _api.get('/v1/classrooms'))['data'], ClassroomRef.fromJson);

  Future<PageOf<Child>> children({
    int? classroomId,
    String? search,
    int page = 1,
  }) async => PageOf.fromJson(
    await _api.get(
      '/v1/children',
      query: {
        'classroom_id': classroomId,
        'q': (search?.isEmpty ?? true) ? null : search,
        'page': page,
        'per_page': 50,
      },
    ),
    Child.fromJson,
  );

  Future<Child> child(int id) async =>
      Child.fromJson((await _api.get('/v1/children/$id'))['data'] as Json);

  Future<AttendanceSheet> sheet({String? date, int? classroomId}) async =>
      AttendanceSheet.fromJson(
        await _api.get(
          '/v1/attendance',
          query: {'date': date, 'classroom_id': classroomId},
        ),
      );

  Future<Attendance> checkIn(int childId, {String method = 'manual'}) async =>
      Attendance.fromJson(
        (await _api.post(
              '/v1/attendance/check-in',
              data: {'child_id': childId, 'method': method},
            ))['data']
            as Json,
      );

  /// Many children at once, with the time each was really scanned (offline sync).
  Future<void> bulkCheckIn(
    List<({int childId, DateTime at})> entries, {
    String method = 'manual',
  }) => _api.post(
    '/v1/attendance/check-in/bulk',
    data: {
      'method': method,
      'children': [
        for (final e in entries)
          {
            'child_id': e.childId,
            'checked_in_at': e.at.toUtc().toIso8601String(),
          },
      ],
    },
  );

  /// Exactly one way of identifying the collector.
  Future<Attendance> checkOut(
    int childId, {
    int? collectorId,
    String? pickupToken,
    String? passCode,
    String? overrideReason,
    String? collectorName,
  }) async {
    final json = await _api.post(
      '/v1/attendance/check-out',
      data: {
        'child_id': childId,
        'collector_id': ?collectorId,
        'pickup_token': ?pickupToken,
        'pass_code': ?passCode,
        'override_reason': ?overrideReason,
        'collector_name': ?collectorName,
      },
    );
    return Attendance.fromJson(json['data'] as Json);
  }

  Future<PickupCheck> verifyPickup({
    String? pickupToken,
    String? passCode,
  }) async => PickupCheck.fromJson(
    (await _api.post(
          '/v1/attendance/pickup/verify',
          data: {'pickup_token': ?pickupToken, 'pass_code': ?passCode},
        ))['data']
        as Json,
  );
}
