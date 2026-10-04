import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/models/json.dart';
import '../core/models/moment.dart';
import '../core/models/page.dart';
import '../core/network/api_client.dart';

/// A new Daily Wall update from a teacher.
class NewMoment {
  const NewMoment({
    required this.type,
    this.clientRef,
    this.body,
    this.payload = const {},
    this.childIds = const [],
    this.classroomId,
    this.exceptChildIds = const [],
    this.photoPaths = const [],
    this.videos = const [],
  });

  final String type;
  final String? body;
  final Map<String, String> payload;
  final List<int> childIds;
  final int? classroomId;
  final List<int> exceptChildIds;
  final List<String> photoPaths;
  final List<NewVideo> videos;

  /// The app's id for this update: a retry never posts it twice.
  final String? clientRef;

  bool get hasMedia => photoPaths.isNotEmpty || videos.isNotEmpty;
}

class NewVideo {
  const NewVideo({required this.path, this.posterPath, this.durationMs});

  final String path;
  final String? posterPath;
  final int? durationMs;
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

  Future<Moment> post(
    NewMoment moment, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fields = <String, dynamic>{
      'type': moment.type,
      'client_ref': ?moment.clientRef,
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

    if (!moment.hasMedia) {
      return Moment.fromJson(
        (await _api.post('/v1/moments', data: fields))['data'] as Json,
      );
    }

    // Media goes as multipart form-data (`child_ids[]`, `payload[meal]`,
    // `photos[]`, `videos[]` with `video_posters[]` / `video_durations[]`).
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
      form.files.add(MapEntry('photos[]', await _file(path)));
    }
    for (final video in moment.videos) {
      form.files.add(MapEntry('videos[]', await _file(video.path)));
      if (video.posterPath != null) {
        form.files.add(
          MapEntry(
            'video_posters[]',
            await _file(video.posterPath!, 'poster.jpg'),
          ),
        );
      }
      if (video.durationMs != null) {
        form.fields.add(MapEntry('video_durations[]', '${video.durationMs}'));
      }
    }

    return Moment.fromJson(
      (await _api.post(
            '/v1/moments',
            data: form,
            onSendProgress: onProgress,
          ))['data']
          as Json,
    );
  }

  /// Streams from disk on phones; reads the picked blob on the web.
  Future<MultipartFile> _file(String path, [String? name]) async {
    final filename = name ?? path.split('/').last;
    if (kIsWeb) {
      return MultipartFile.fromBytes(
        await XFile(path).readAsBytes(),
        filename: filename,
      );
    }
    return MultipartFile.fromFile(path, filename: filename);
  }

  Future<void> delete(int momentId) => _api.delete('/v1/moments/$momentId');
}
