import '../core/models/app_notification.dart';
import '../core/models/json.dart';
import '../core/models/page.dart';
import '../core/network/api_client.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<PageOf<AppNotification>> inbox({
    bool unreadOnly = false,
    int page = 1,
  }) async => PageOf.fromJson(
    await _api.get(
      '/v1/me/notifications',
      query: {'unread': unreadOnly ? 1 : null, 'page': page},
    ),
    AppNotification.fromJson,
  );

  Future<AppNotification> markRead(int id) async => AppNotification.fromJson(
    (await _api.post('/v1/me/notifications/$id/read'))['data'] as Json,
  );

  Future<void> markAllRead() => _api.post('/v1/me/notifications/read-all');
}
