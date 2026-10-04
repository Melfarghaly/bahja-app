import 'outbox_files_stub.dart'
    if (dart.library.io) 'outbox_files_io.dart'
    as platform;

/// Picked photos/videos live in temporary folders the OS may clear: queued
/// media is copied into the app's own folder until it is uploaded.
Future<String> keepFile(String path, String itemId) =>
    platform.keepFile(path, itemId);

Future<void> dropFiles(String itemId) => platform.dropFiles(itemId);
