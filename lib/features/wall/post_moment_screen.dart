import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/outbox.dart';
import '../../app/providers.dart';
import '../../core/models/child.dart';
import '../../core/theme/app_theme.dart';
import '../../data/wall_repository.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import 'moment_card.dart';

final _classroomsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(staffRepositoryProvider).classrooms(),
);
final _classroomChildrenProvider = FutureProvider.autoDispose
    .family<List<Child>, int>(
      (ref, id) async =>
          (await ref.watch(staffRepositoryProvider).children(classroomId: id))
              .items,
    );

/// Post in two taps: pick a type, pick children (or the whole class), post.
class PostMomentScreen extends ConsumerStatefulWidget {
  const PostMomentScreen({super.key});

  @override
  ConsumerState<PostMomentScreen> createState() => _PostMomentScreenState();
}

class _PostMomentScreenState extends ConsumerState<PostMomentScreen> {
  static const _types = [
    'photo',
    'meal',
    'nap',
    'diaper',
    'mood',
    'activity',
    'note',
    'health',
    'incident',
  ];

  String _type = 'meal';
  int? _classroomId;
  bool _wholeClass = true;
  final Set<int> _selected = {};
  final _body = TextEditingController();
  final _title = TextEditingController();
  final Map<String, String> _payload = {'meal': 'lunch', 'amount': 'all'};
  TimeOfDay _napFrom = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _napTo = const TimeOfDay(hour: 14, minute: 0);
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  String? _localProblem;
  bool _busy = false;

  String _label(String type) {
    final ar = S.of(context).isArabic;
    return switch (type) {
      'photo' => ar ? 'صور' : 'Photos',
      'video' => ar ? 'فيديو' : 'Video',
      'meal' => ar ? 'وجبة' : 'Meal',
      'nap' => ar ? 'نوم' : 'Nap',
      'diaper' => ar ? 'حفاض' : 'Diaper',
      'mood' => ar ? 'مزاج' : 'Mood',
      'activity' => ar ? 'نشاط' : 'Activity',
      'health' => ar ? 'صحة' : 'Health',
      'incident' => ar ? 'حادثة' : 'Incident',
      _ => ar ? 'ملاحظة' : 'Note',
    };
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Map<String, String> _payloadFor(String type) => switch (type) {
    'meal' => {'meal': _payload['meal']!, 'amount': _payload['amount']!},
    'nap' => {'from': _hhmm(_napFrom), 'to': _hhmm(_napTo)},
    'diaper' => {'kind': _payload['kind'] ?? 'wet'},
    'mood' => {'mood': _payload['mood'] ?? 'happy'},
    'activity' => {'title': _title.text.trim()},
    _ => const {},
  };

  /// Checked here so the teacher sees problems now, not after the upload:
  /// required fields, and photo consent for everyone in a photo or video.
  String? _localError(bool ar) {
    if (['note', 'health', 'incident'].contains(_type) &&
        _body.text.trim().isEmpty) {
      return ar ? 'اكتبي النص أولاً' : 'Write the text first';
    }
    if (_type == 'activity' && _title.text.trim().isEmpty) {
      return ar ? 'اكتبي عنوان النشاط' : 'Add the activity title';
    }
    if (_type == 'photo' && _photos.isEmpty) {
      return ar ? 'أضيفي صورة واحدة على الأقل' : 'Add at least one photo';
    }
    if (_type == 'video' && _videos.isEmpty) {
      return ar ? 'أضيفي فيديو' : 'Add a video';
    }
    if (!_wholeClass && _selected.isEmpty) {
      return ar ? 'اختاري الأطفال' : 'Choose the children';
    }

    if (_photos.isNotEmpty || _videos.isNotEmpty) {
      final id = _classroomId;
      final children = id == null
          ? null
          : ref.read(_classroomChildrenProvider(id)).value;
      if (children != null) {
        final tagged = _wholeClass
            ? children
            : children.where((c) => _selected.contains(c.id)).toList();
        final group = tagged.length > 1;
        final missing = tagged
            .where(
              (c) =>
                  c.photoConsentWall == false ||
                  (group && c.photoConsentGroup == false),
            )
            .map((c) => c.firstName)
            .toList();
        if (missing.isNotEmpty) {
          final names = missing.join('، ');
          return group
              ? (ar
                    ? 'لا يوجد إذن بالظهور في الصور الجماعية لـ: $names'
                    : 'No group-photo permission for: $names')
              : (ar
                    ? 'لا يوجد إذن تصوير لـ: $names'
                    : 'No photo permission for: $names');
        }
      }
    }
    return null;
  }

  /// Saved on the phone and sent in the background: the screen closes at once.
  Future<void> _submit() async {
    final s = S.of(context);
    final problem = _localError(s.isArabic);
    if (problem != null) {
      setState(() => _localProblem = problem);
      return;
    }

    setState(() => _busy = true);
    final count = _wholeClass ? null : _selected.length;
    await ref
        .read(outboxProvider.notifier)
        .addMoment(
          NewMoment(
            type: _type,
            body: _body.text,
            payload: _payloadFor(_type),
            classroomId: _wholeClass ? _classroomId : null,
            childIds: _wholeClass ? const [] : _selected.toList(),
            photoPaths: _photos.map((p) => p.path).toList(),
            videos: _videos.map((v) => NewVideo(path: v.path)).toList(),
          ),
          label:
              '${_label(_type)} · ${count == null ? s.wholeClass : '$count ${s.isArabic ? 'طفل' : 'children'}'}',
        );
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ar = s.isArabic;
    final classrooms = ref.watch(_classroomsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.newMoment)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _types)
                ChoiceChip(
                  avatar: Icon(momentIcon(type), size: 18),
                  label: Text(_label(type)),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AsyncView(
            value: classrooms,
            builder: (list) {
              _classroomId ??= list.isEmpty ? null : list.first.id;
              return DropdownButtonFormField<int>(
                initialValue: _classroomId,
                decoration: InputDecoration(
                  labelText: ar ? 'الفصل' : 'Classroom',
                ),
                items: [
                  for (final c in list)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (id) => setState(() {
                  _classroomId = id;
                  _selected.clear();
                }),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.wholeClass),
            value: _wholeClass && _type != 'incident',
            onChanged: _type == 'incident'
                ? null
                : (v) => setState(() => _wholeClass = v),
          ),
          if (!_wholeClass || _type == 'incident') _childPicker(),
          const SizedBox(height: 12),
          ..._typeFields(ar),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 4,
            decoration: InputDecoration(labelText: ar ? 'النص' : 'Text'),
          ),
          const SizedBox(height: 12),
          _photoPicker(s),
          if (_localProblem != null) ...[
            const SizedBox(height: 8),
            Text(
              _localProblem!,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(s.post),
          ),
        ],
      ),
    );
  }

  Widget _childPicker() {
    final id = _classroomId;
    if (id == null) return const SizedBox.shrink();
    return AsyncView(
      value: ref.watch(_classroomChildrenProvider(id)),
      builder: (children) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final child in children)
            FilterChip(
              label: Text(child.firstName),
              selected: _selected.contains(child.id),
              onSelected: (on) => setState(
                () => on ? _selected.add(child.id) : _selected.remove(child.id),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _typeFields(bool ar) {
    Widget choice(String key, Map<String, String> options) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: (_payload[key] ?? options.keys.first) == e.key,
            onSelected: (_) => setState(() => _payload[key] = e.key),
          ),
      ],
    );

    return switch (_type) {
      'meal' => [
        choice(
          'meal',
          ar
              ? {'breakfast': 'الإفطار', 'lunch': 'الغداء', 'snack': 'السناك'}
              : {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'snack': 'Snack'},
        ),
        const SizedBox(height: 8),
        choice(
          'amount',
          ar
              ? {
                  'all': 'أكل كله',
                  'most': 'معظمه',
                  'half': 'نصفه',
                  'little': 'قليلاً',
                  'none': 'لم يأكل',
                }
              : {
                  'all': 'All',
                  'most': 'Most',
                  'half': 'Half',
                  'little': 'A little',
                  'none': 'None',
                },
        ),
      ],
      'nap' => [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(true),
                child: Text('${ar ? 'من' : 'From'} ${_hhmm(_napFrom)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(false),
                child: Text('${ar ? 'إلى' : 'To'} ${_hhmm(_napTo)}'),
              ),
            ),
          ],
        ),
      ],
      'diaper' => [
        choice(
          'kind',
          ar
              ? {'wet': 'مبلل', 'dirty': 'متسخ', 'dry': 'جاف'}
              : {'wet': 'Wet', 'dirty': 'Dirty', 'dry': 'Dry'},
        ),
      ],
      'mood' => [
        choice(
          'mood',
          ar
              ? {
                  'happy': 'سعيد',
                  'calm': 'هادئ',
                  'tired': 'متعب',
                  'sad': 'حزين',
                  'upset': 'منزعج',
                }
              : {
                  'happy': 'Happy',
                  'calm': 'Calm',
                  'tired': 'Tired',
                  'sad': 'Sad',
                  'upset': 'Upset',
                },
        ),
      ],
      'activity' => [
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: ar ? 'عنوان النشاط' : 'Activity',
          ),
        ),
      ],
      _ => const [],
    };
  }

  Future<void> _pickTime(bool from) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from ? _napFrom : _napTo,
    );
    if (picked != null) {
      setState(() => from ? _napFrom = picked : _napTo = picked);
    }
  }

  Widget _photoPicker(S s) {
    final ar = s.isArabic;
    final picker = ImagePicker();

    Future<void> addPhotos(ImageSource source) async {
      // Resized and compressed on the phone: a 12 MP photo uploads as ~300 KB.
      final picked = source == ImageSource.camera
          ? [
              ?await picker.pickImage(
                source: source,
                maxWidth: 1600,
                imageQuality: 80,
              ),
            ]
          : await picker.pickMultiImage(
              maxWidth: 1600,
              imageQuality: 80,
              limit: 10,
            );
      setState(() => _photos.addAll(picked.take(10 - _photos.length)));
    }

    Future<void> addVideo(ImageSource source) async {
      // Short clips only; compressed to 720p in the background before upload.
      final video = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (video != null && _videos.length < 3) {
        setState(() => _videos.add(video));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in _photos)
              InputChip(
                avatar: const Icon(Icons.photo_outlined, size: 18),
                label: Text(photo.name, overflow: TextOverflow.ellipsis),
                onDeleted: () => setState(() => _photos.remove(photo)),
              ),
            for (final video in _videos)
              InputChip(
                avatar: const Icon(Icons.videocam_outlined, size: 18),
                label: Text(video.name, overflow: TextOverflow.ellipsis),
                onDeleted: () => setState(() => _videos.remove(video)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.photo_camera_outlined),
              label: Text(ar ? 'صورة' : 'Photo'),
              onPressed: () => addPhotos(ImageSource.camera),
            ),
            ActionChip(
              avatar: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(s.addPhotos),
              onPressed: () => addPhotos(ImageSource.gallery),
            ),
            ActionChip(
              avatar: const Icon(Icons.videocam_outlined),
              label: Text(ar ? 'تصوير فيديو' : 'Record video'),
              onPressed: () => addVideo(ImageSource.camera),
            ),
            ActionChip(
              avatar: const Icon(Icons.video_library_outlined),
              label: Text(ar ? 'فيديو من المعرض' : 'Video from gallery'),
              onPressed: () => addVideo(ImageSource.gallery),
            ),
          ],
        ),
      ],
    );
  }
}
