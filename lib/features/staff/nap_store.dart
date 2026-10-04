import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Who is asleep right now (child id → since when), per nursery and day,
/// kept on the device so a nap survives closing the app.
class NapStore {
  String _key(int tenantId, DateTime day) =>
      'naps.$tenantId.${day.year}-${day.month}-${day.day}';

  Future<Map<int, DateTime>> load(int tenantId) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _key(tenantId, DateTime.now()),
    );
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), DateTime.parse(v as String)),
    );
  }

  Future<void> save(int tenantId, Map<int, DateTime> naps) async =>
      (await SharedPreferences.getInstance()).setString(
        _key(tenantId, DateTime.now()),
        jsonEncode(naps.map((k, v) => MapEntry('$k', v.toIso8601String()))),
      );
}
