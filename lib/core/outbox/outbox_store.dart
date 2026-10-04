import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'outbox_item.dart';

/// Keeps the queue on the device between launches.
abstract class OutboxStore {
  Future<List<OutboxItem>> load();
  Future<void> save(List<OutboxItem> items);
}

class PrefsOutboxStore implements OutboxStore {
  static const _key = 'outbox.v1';

  @override
  Future<List<OutboxItem>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(OutboxItem.fromJson)
          .toList();
    } catch (_) {
      return []; // never block the app on a corrupt queue
    }
  }

  @override
  Future<void> save(List<OutboxItem> items) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode([for (final i in items) i.toJson()]),
      );
}

/// For tests.
class MemoryOutboxStore implements OutboxStore {
  List<OutboxItem> items = [];

  @override
  Future<List<OutboxItem>> load() async => List.of(items);

  @override
  Future<void> save(List<OutboxItem> items) async =>
      this.items = List.of(items);
}
