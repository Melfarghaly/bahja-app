/// Small helpers for reading API JSON safely.
typedef Json = Map<String, dynamic>;

DateTime? parseDate(Object? value) => value is String && value.isNotEmpty
    ? DateTime.parse(value).toLocal()
    : null;

int? asInt(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  final String v => int.tryParse(v),
  _ => null,
};

bool asBool(Object? value) => value == true || value == 1 || value == '1';

List<T> asList<T>(Object? value, T Function(Json) fromJson) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
