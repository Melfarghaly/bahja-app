import 'video_tools.dart';

/// Web: no native compressor, upload as picked.
Future<PreparedVideo> prepareVideo(String path) async =>
    PreparedVideo(path: path);

Future<void> clearVideoCache() async {}
