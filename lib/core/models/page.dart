import 'json.dart';

/// One page of a Laravel paginated response (`data` + `meta`).
class PageOf<T> {
  const PageOf({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.extra = const {},
  });

  factory PageOf.fromJson(Json json, T Function(Json) fromJson) {
    final meta = json['meta'] as Json? ?? const {};
    return PageOf(
      items: asList(json['data'], fromJson),
      currentPage: asInt(meta['current_page']) ?? 1,
      lastPage: asInt(meta['last_page']) ?? 1,
      extra: json,
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;

  /// The whole response, for top-level extras such as `unread_count`.
  final Json extra;

  bool get hasMore => currentPage < lastPage;
}
