import 'video_tools_stub.dart'
    if (dart.library.io) 'video_tools_io.dart'
    as platform;

/// A video ready to upload: compressed, with a poster frame and duration.
class PreparedVideo {
  const PreparedVideo({required this.path, this.posterPath, this.durationMs});

  final String path;
  final String? posterPath;
  final int? durationMs;
}

/// Compresses to 720p on the phone before upload (a 30 s clip goes from
/// ~60 MB to ~5 MB: faster for the teacher, lighter for every family) and
/// grabs a poster frame. Falls back to the original file if anything fails.
Future<PreparedVideo> prepareVideo(String path) => platform.prepareVideo(path);

/// Frees the compressor's temporary files once uploaded.
Future<void> clearVideoCache() => platform.clearVideoCache();
