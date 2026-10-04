import 'json.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    this.childId,
    this.deepLink = const {},
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: asInt(json['id'])!,
    type: json['type'] as String? ?? '',
    priority: json['priority'] as String? ?? 'normal',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    childId: asInt(json['child_id']),
    deepLink: json['deep_link'] is Json ? json['deep_link'] as Json : const {},
    read: asBool(json['read']),
    createdAt: parseDate(json['created_at']) ?? DateTime.now(),
  );

  final int id;
  final String type;
  final String priority;
  final String title;
  final String body;
  final int? childId;
  final Json deepLink;
  final bool read;
  final DateTime createdAt;

  bool get urgent => priority == 'high' || priority == 'emergency';
}
