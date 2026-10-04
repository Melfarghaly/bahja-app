import 'package:video_compress/video_compress.dart';

import 'video_tools.dart';

Future<PreparedVideo> prepareVideo(String path) async {
  String output = path;
  int? durationMs;
  try {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.Res1280x720Quality,
      includeAudio: true,
    );
    if (info?.path != null) output = info!.path!;
    durationMs = info?.duration?.round();
  } catch (_) {
    // Upload the original rather than lose the moment.
  }

  String? poster;
  try {
    poster = (await VideoCompress.getFileThumbnail(path, quality: 75)).path;
  } catch (_) {
    poster = null;
  }

  return PreparedVideo(
    path: output,
    posterPath: poster,
    durationMs: durationMs,
  );
}

Future<void> clearVideoCache() async {
  try {
    await VideoCompress.deleteAllCache();
  } catch (_) {}
}
