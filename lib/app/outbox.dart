import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/media/video_tools.dart';
import '../core/network/api_exception.dart';
import '../core/outbox/outbox_files.dart';
import '../core/outbox/outbox_item.dart';
import '../core/outbox/outbox_store.dart';
import '../data/wall_repository.dart';
import 'providers.dart';

/// Overridden in tests with a [MemoryOutboxStore].
final outboxStoreProvider = Provider<OutboxStore>((ref) => PrefsOutboxStore());

class OutboxState {
  const OutboxState({
    this.items = const [],
    this.syncing = false,
    this.uploadingId,
    this.progress,
    this.delivered = 0,
  });

  final List<OutboxItem> items;
  final bool syncing;

  /// The item whose files are uploading now, and how far (0..1).
  final String? uploadingId;
  final double? progress;

  /// Grows each time something reaches the server: screens reload on change.
  final int delivered;

  List<OutboxItem> get pending => items.where((i) => !i.failed).toList();
  List<OutboxItem> get failed => items.where((i) => i.failed).toList();

  /// Children checked in on this device but not yet confirmed by the server.
  Set<int> get pendingCheckIns => {
    for (final i in items)
      if (i.kind == OutboxKind.checkIn && !i.failed && i.childId != null)
        i.childId!,
  };

  OutboxState copyWith({
    List<OutboxItem>? items,
    bool? syncing,
    String? uploadingId,
    double? progress,
    int? delivered,
    bool clearUpload = false,
  }) => OutboxState(
    items: items ?? this.items,
    syncing: syncing ?? this.syncing,
    uploadingId: clearUpload ? null : (uploadingId ?? this.uploadingId),
    progress: clearUpload ? null : (progress ?? this.progress),
    delivered: delivered ?? this.delivered,
  );
}

final outboxProvider = NotifierProvider<OutboxController, OutboxState>(
  OutboxController.new,
);

/// Offline-first sending for the teacher: every action is saved on the
/// device and acknowledged instantly, then sent in the background - check-ins
/// together in one request, updates one by one with upload progress.
/// Network trouble → retry with backoff; a refusal by the server → kept with
/// its message so the teacher can retry or discard it.
class OutboxController extends Notifier<OutboxState>
    with WidgetsBindingObserver {
  static const _backoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
  ];

  Timer? _retry;

  /// Something was queued while a send was running: send again after it.
  bool _again = false;
  int _failures = 0;
  final _uuid = const Uuid();

  @override
  OutboxState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _retry?.cancel();
    });
    Future.microtask(_restore);
    return const OutboxState();
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) unawaited(flush());
  }

  Future<void> _restore() async {
    final saved = await ref.read(outboxStoreProvider).load();
    if (saved.isEmpty) return;
    state = state.copyWith(
      items: [
        ...saved,
        ...state.items.where((i) => !saved.any((s) => s.id == i.id)),
      ],
    );
    unawaited(flush());
  }

  int? get _tenantId => ref.read(sessionStoreProvider).tenantId;

  /// Queue a wall update. Returns at once; media is copied, then uploaded.
  Future<void> addMoment(NewMoment moment, {required String label}) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final id = _uuid.v4();

    final photos = [for (final p in moment.photoPaths) await keepFile(p, id)];
    final videos = [
      for (final v in moment.videos)
        NewVideo(
          path: await keepFile(v.path, id),
          posterPath: v.posterPath == null
              ? null
              : await keepFile(v.posterPath!, id),
          durationMs: v.durationMs,
        ),
    ];

    await _add(
      OutboxItem(
        id: id,
        kind: OutboxKind.moment,
        tenantId: tenantId,
        label: label,
        createdAt: DateTime.now(),
        data: {
          'type': moment.type,
          'body': ?moment.body,
          if (moment.payload.isNotEmpty) 'payload': moment.payload,
          if (moment.classroomId != null)
            'classroom_id': moment.classroomId
          else
            'child_ids': moment.childIds,
          if (moment.exceptChildIds.isNotEmpty)
            'except_child_ids': moment.exceptChildIds,
        },
        photoPaths: photos,
        videos: videos,
      ),
    );
  }

  /// Check children in now (the time of the tap is what is recorded).
  Future<void> checkIn(Iterable<({int id, String name})> children) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final now = DateTime.now();
    for (final child in children) {
      if (state.pendingCheckIns.contains(child.id)) continue;
      state = state.copyWith(
        items: [
          ...state.items,
          OutboxItem(
            id: _uuid.v4(),
            kind: OutboxKind.checkIn,
            tenantId: tenantId,
            label: child.name,
            createdAt: now,
            data: {
              'child_id': child.id,
              'checked_in_at': now.toUtc().toIso8601String(),
            },
          ),
        ],
      );
    }
    await _persist();
    unawaited(flush());
  }

  Future<void> _add(OutboxItem item) async {
    state = state.copyWith(items: [...state.items, item]);
    await _persist();
    unawaited(flush());
  }

  Future<void> retry(String id) async {
    state = state.copyWith(
      items: [
        for (final i in state.items)
          i.id == id ? i.copyWith(clearError: true) : i,
      ],
    );
    await _persist();
    unawaited(flush());
  }

  Future<void> discard(String id) async {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
    await _persist();
    await dropFiles(id);
  }

  /// Send everything that is waiting, for the nursery currently open.
  Future<void> flush() async {
    if (state.syncing) {
      _again = true;
      return;
    }
    _again = false;
    final tenantId = _tenantId;
    if (tenantId == null) return;
    _retry?.cancel();
    state = state.copyWith(syncing: true);

    try {
      // 1. All check-ins in one request.
      final checkIns = state.pending
          .where((i) => i.kind == OutboxKind.checkIn && i.tenantId == tenantId)
          .toList();
      if (checkIns.isNotEmpty) {
        await _attempt(
          checkIns,
          () => ref.read(staffRepositoryProvider).bulkCheckIn([
            for (final i in checkIns)
              (
                childId: i.childId!,
                at: DateTime.parse(i.data['checked_in_at'] as String),
              ),
          ]),
        );
      }

      // 2. Updates, oldest first.
      for (final item
          in state.pending
              .where(
                (i) => i.kind == OutboxKind.moment && i.tenantId == tenantId,
              )
              .toList()) {
        state = state.copyWith(
          uploadingId: item.hasMedia ? item.id : null,
          progress: item.hasMedia ? 0 : null,
        );
        final ready = await _prepareVideos(item);
        await _attempt(
          [ready],
          () => ref
              .read(wallRepositoryProvider)
              .post(
                ready.toMoment(),
                onProgress: (sent, total) {
                  if (total > 0) state = state.copyWith(progress: sent / total);
                },
              ),
        );
        state = state.copyWith(clearUpload: true);
      }
      _failures = 0;
      if (state.items.every(
        (i) => i.failed || i.kind != OutboxKind.moment || !i.hasMedia,
      )) {
        unawaited(clearVideoCache());
      }
    } on _Offline {
      // Back off and try again; nothing is lost.
      final delay = _backoff[_failures.clamp(0, _backoff.length - 1)];
      _failures++;
      _retry = Timer(delay, () => unawaited(flush()));
      _again = false; // the retry timer will pick them up
    } finally {
      state = state.copyWith(syncing: false, clearUpload: true);
    }
    if (_again) await flush();
  }

  /// Videos are compressed (and get a poster) here, in the background, so
  /// the teacher never waits for it. Done once: the result is saved.
  Future<OutboxItem> _prepareVideos(OutboxItem item) async {
    if (item.videos.every(
      (v) => v.posterPath != null || v.durationMs != null,
    )) {
      return item;
    }

    final prepared = <NewVideo>[];
    for (final video in item.videos) {
      if (video.posterPath != null || video.durationMs != null) {
        prepared.add(video);
        continue;
      }
      final ready = await prepareVideo(video.path);
      prepared.add(
        NewVideo(
          path: ready.path == video.path
              ? video.path
              : await keepFile(ready.path, item.id),
          posterPath: ready.posterPath == null
              ? null
              : await keepFile(ready.posterPath!, item.id),
          durationMs: ready.durationMs ?? 0,
        ),
      );
    }

    final updated = item.copyWith(videos: prepared);
    state = state.copyWith(
      items: [for (final i in state.items) i.id == item.id ? updated : i],
    );
    await _persist();
    return updated;
  }

  /// Runs one send. Success removes the items; a refusal marks them failed;
  /// a network problem stops this round.
  Future<void> _attempt(
    List<OutboxItem> items,
    Future<Object?> Function() send,
  ) async {
    final ids = {for (final i in items) i.id};
    try {
      await send();
      state = state.copyWith(
        items: state.items.where((i) => !ids.contains(i.id)).toList(),
        delivered: state.delivered + 1,
      );
      for (final id in ids) {
        await dropFiles(id);
      }
    } on ApiException catch (e) {
      final transient =
          e.code == 'network_error' ||
          (e.statusCode ?? 500) >= 500 ||
          e.statusCode == 429 ||
          e.statusCode == 401;
      if (transient) {
        state = state.copyWith(
          items: [
            for (final i in state.items)
              ids.contains(i.id) ? i.copyWith(attempts: i.attempts + 1) : i,
          ],
        );
        await _persist();
        throw const _Offline();
      }
      state = state.copyWith(
        items: [
          for (final i in state.items)
            ids.contains(i.id) ? i.copyWith(error: e.message) : i,
        ],
      );
    }
    await _persist();
  }

  Future<void> _persist() => ref.read(outboxStoreProvider).save(state.items);
}

class _Offline implements Exception {
  const _Offline();
}
