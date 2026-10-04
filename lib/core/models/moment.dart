import 'json.dart';

class MomentPhoto {
  const MomentPhoto({
    required this.id,
    required this.url,
    required this.thumbUrl,
    this.width,
    this.height,
    this.expiresAt,
  });

  factory MomentPhoto.fromJson(Json json) => MomentPhoto(
    id: asInt(json['id'])!,
    url: json['url'] as String,
    thumbUrl: json['thumb_url'] as String?,
    width: asInt(json['width']),
    height: asInt(json['height']),
    expiresAt: parseDate(json['expires_at']),
  );

  final int id;

  /// Signed, expiring links: use directly, no auth header.
  final String url;
  final String? thumbUrl;
  final int? width;
  final int? height;
  final DateTime? expiresAt;

  double get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : 4 / 3;
}

/// A short video: streamable (HTTP Range) from a signed, expiring link.
class MomentVideo {
  const MomentVideo({
    required this.id,
    required this.url,
    this.posterUrl,
    this.width,
    this.height,
    this.durationMs,
    this.size,
  });

  factory MomentVideo.fromJson(Json json) => MomentVideo(
    id: asInt(json['id'])!,
    url: json['url'] as String,
    posterUrl: json['poster_url'] as String?,
    width: asInt(json['width']),
    height: asInt(json['height']),
    durationMs: asInt(json['duration_ms']),
    size: asInt(json['size']),
  );

  final int id;
  final String url;
  final String? posterUrl;
  final int? width;
  final int? height;
  final int? durationMs;
  final int? size;

  double get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : 16 / 9;

  /// "0:42"
  String get durationLabel {
    final seconds = ((durationMs ?? 0) / 1000).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class MomentChild {
  const MomentChild({
    required this.id,
    required this.firstName,
    this.acknowledgedAt,
  });

  factory MomentChild.fromJson(Json json) => MomentChild(
    id: asInt(json['id'])!,
    firstName: json['first_name'] as String? ?? '',
    acknowledgedAt: parseDate(json['acknowledged_at']),
  );

  final int id;
  final String firstName;
  final DateTime? acknowledgedAt;
}

/// A Daily Wall update.
class Moment {
  const Moment({
    required this.id,
    required this.type,
    required this.summary,
    this.body,
    this.payload = const {},
    this.authorName,
    this.classroomName,
    this.children = const [],
    this.photos = const [],
    this.videos = const [],
    this.requiresAck = false,
    required this.publishedAt,
  });

  factory Moment.fromJson(Json json) => Moment(
    id: asInt(json['id'])!,
    type: json['type'] as String? ?? 'note',
    summary: json['summary'] as String? ?? '',
    body: json['body'] as String?,
    payload: json['payload'] is Json ? json['payload'] as Json : const {},
    authorName: (json['author'] as Json?)?['name'] as String?,
    classroomName: (json['classroom'] as Json?)?['name'] as String?,
    children: asList(json['children'], MomentChild.fromJson),
    photos: asList(json['photos'], MomentPhoto.fromJson),
    videos: asList(json['videos'], MomentVideo.fromJson),
    requiresAck: asBool(json['requires_ack']),
    publishedAt: parseDate(json['published_at']) ?? DateTime.now(),
  );

  final int id;

  /// photo / note / meal / nap / diaper / mood / activity / health / incident
  final String type;
  final String summary;
  final String? body;
  final Json payload;
  final String? authorName;
  final String? classroomName;
  final List<MomentChild> children;
  final List<MomentPhoto> photos;
  final List<MomentVideo> videos;
  final bool requiresAck;
  final DateTime publishedAt;

  /// For a family: has my child's incident been acknowledged?
  bool get acknowledged =>
      children.isNotEmpty && children.every((c) => c.acknowledgedAt != null);
}
