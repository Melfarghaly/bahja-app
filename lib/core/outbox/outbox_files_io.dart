import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> _dir(String itemId) async => Directory(
  '${(await getApplicationSupportDirectory()).path}/outbox/$itemId',
);

Future<String> keepFile(String path, String itemId) async {
  final dir = await _dir(itemId);
  await dir.create(recursive: true);
  final name = path.split(Platform.pathSeparator).last;
  return (await File(path).copy('${dir.path}/$name')).path;
}

Future<void> dropFiles(String itemId) async {
  try {
    final dir = await _dir(itemId);
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {}
}
