import 'package:dio/dio.dart';

import '../core/models/json.dart';
import '../core/models/moment.dart';
import '../core/models/page.dart';
import '../core/network/api_client.dart';

/// A new Daily Wall update from a teacher.
class NewMoment {
  const NewMoment({
    required this.type,
    this.body,
    this.payload = const {},
    this.childIds = const [],
    this.classroomId,
    this.exceptChildIds = const [],
    this.photoPaths = const [],
  });

  final String type;
  final String? body;
  final Map<String, String> payload;
  final List<int> childIds;
  final int? classroomId;
  final List<int> exceptChildIds;
  final List<String> photoPaths;
}

class WallRepository {
  WallRepository(this._api);

  final ApiClient _api;

  Future<PageOf<Moment>> wardWall(int childId, {int page = 1}) async =>
      PageOf.fromJson(
        await _api.get('/v1/me/wards/$childId/moments', query: {'page': page}),
        Moment.fromJson,
      );

  Future<Moment> acknowledge(int childId, int momentId) async =>
      Moment.fromJson(
        (await _api.post(
              '/v1/me/wards/$childId/moments/$momentId/acknowledge',
            ))['data']
            as Json,
      );

  Future<PageOf<Moment>> staffWall({
    int? classroomId,
    int? childId,
    int page = 1,
  }) async => PageOf.fromJson(
    await _api.get(
      '/v1/moments',
      query: {'classroom_id': classroomId, 'child_id': childId, 'page': page},
    ),
    Moment.fromJson,
  );

  Future<Moment> post(NewMoment moment) async {
    final fields = <String, dynamic>{
      'type': moment.type,
      if (moment.body != null && moment.body!.trim().isNotEmpty)
        'body': moment.body!.trim(),
      if (moment.payload.isNotEmpty) 'payload': moment.payload,
      if (moment.classroomId != null)
        'classroom_id': moment.classroomId
      else
        'child_ids': moment.childIds,
      if (moment.classroomId != null && moment.exceptChildIds.isNotEmpty)
        'except_child_ids': moment.exceptChildIds,
    };

    if (moment.photoPaths.isEmpty) {
      return Moment.fromJson(
        (await _api.post('/v1/moments', data: fields))['data'] as Json,
      );
    }

    // Photos go as multipart form-data (`child_ids[]`, `payload[meal]`, `photos[]`).
    final form = FormData();
    fields.forEach((key, value) {
      if (value is List) {
        for (final item in value) {
          form.fields.add(MapEntry('$key[]', '$item'));
        }
      } else if (value is Map) {
        value.forEach((k, v) => form.fields.add(MapEntry('$key[$k]', '$v')));
      } else {
        form.fields.add(MapEntry(key, '$value'));
      }
    });
    for (final path in moment.photoPaths) {
      form.files.add(
        MapEntry(
          'photos[]',
          await MultipartFile.fromFile(path, filename: path.split('/').last),
        ),
      );
    }

    return Moment.fromJson(
      (await _api.post('/v1/moments', data: form))['data'] as Json,
    );
  }

  Future<void> delete(int momentId) => _api.delete('/v1/moments/$momentId');
}
