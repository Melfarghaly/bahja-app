import '../../data/wall_repository.dart';

enum OutboxKind { moment, checkIn }

/// Something the teacher did that is waiting to reach the server. Saved on
/// the device first, so the teacher moves on at once and nothing is lost
/// when the network drops.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.tenantId,
    required this.label,
    required this.createdAt,
    this.data = const {},
    this.photoPaths = const [],
    this.videos = const [],
    this.attempts = 0,
    this.error,
  });

  factory OutboxItem.fromJson(Map<String, dynamic> json) => OutboxItem(
    id: json['id'] as String,
    kind: OutboxKind.values.byName(json['kind'] as String),
    tenantId: json['tenant_id'] as int,
    label: json['label'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    data: (json['data'] as Map<String, dynamic>? ?? const {}),
    photoPaths: (json['photos'] as List<dynamic>? ?? const []).cast<String>(),
    videos: (json['videos'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (v) => NewVideo(
            path: v['path'] as String,
            posterPath: v['poster'] as String?,
            durationMs: v['duration_ms'] as int?,
          ),
        )
        .toList(),
    attempts: json['attempts'] as int? ?? 0,
    error: json['error'] as String?,
  );

  /// Also the moment's `client_ref`: retries never duplicate it.
  final String id;
  final OutboxKind kind;
  final int tenantId;

  /// What the teacher sees in the queue ("وجبة الغداء · 12 طفل").
  final String label;
  final DateTime createdAt;

  /// Moment fields, or {child_id, checked_in_at} for a check-in.
  final Map<String, dynamic> data;
  final List<String> photoPaths;
  final List<NewVideo> videos;
  final int attempts;

  /// Set when the server refused it for good (shown with retry / discard).
  final String? error;

  bool get failed => error != null;
  bool get hasMedia => photoPaths.isNotEmpty || videos.isNotEmpty;

  int? get childId => data['child_id'] as int?;

  NewMoment toMoment() => NewMoment(
    clientRef: id,
    type: data['type'] as String,
    body: data['body'] as String?,
    payload: (data['payload'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, '$v'),
    ),
    childIds: (data['child_ids'] as List<dynamic>? ?? const []).cast<int>(),
    classroomId: data['classroom_id'] as int?,
    exceptChildIds: (data['except_child_ids'] as List<dynamic>? ?? const [])
        .cast<int>(),
    photoPaths: photoPaths,
    videos: videos,
  );

  OutboxItem copyWith({
    int? attempts,
    String? error,
    List<NewVideo>? videos,
    bool clearError = false,
  }) => OutboxItem(
    id: id,
    kind: kind,
    tenantId: tenantId,
    label: label,
    createdAt: createdAt,
    data: data,
    photoPaths: photoPaths,
    videos: videos ?? this.videos,
    attempts: attempts ?? this.attempts,
    error: clearError ? null : (error ?? this.error),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'tenant_id': tenantId,
    'label': label,
    'created_at': createdAt.toIso8601String(),
    'data': data,
    'photos': photoPaths,
    'videos': [
      for (final v in videos)
        {'path': v.path, 'poster': v.posterPath, 'duration_ms': v.durationMs},
    ],
    'attempts': attempts,
    'error': error,
  };
}
