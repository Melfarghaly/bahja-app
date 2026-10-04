import 'package:flutter/material.dart';

import '../../core/models/moment.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';

IconData momentIcon(String type) => switch (type) {
  'photo' => Icons.photo_camera_outlined,
  'meal' => Icons.restaurant_rounded,
  'nap' => Icons.bedtime_outlined,
  'diaper' => Icons.baby_changing_station_outlined,
  'mood' => Icons.mood_rounded,
  'activity' => Icons.palette_outlined,
  'health' => Icons.healing_outlined,
  'incident' => Icons.report_gmailerrorred_rounded,
  _ => Icons.sticky_note_2_outlined,
};

/// One wall update. Photos are signed links: loaded directly, no auth header.
class MomentCard extends StatelessWidget {
  const MomentCard({
    super.key,
    required this.moment,
    this.showChildren = false,
    this.onAcknowledge,
    this.onDelete,
  });

  final Moment moment;
  final bool showChildren;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.isArabic ? 'ar' : 'en';
    final incident = moment.requiresAck;

    return Card(
      shape: incident
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.warning, width: 1.5),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: (incident ? AppColors.warning : AppColors.teal)
                  .withValues(alpha: 0.12),
              child: Icon(
                momentIcon(moment.type),
                color: incident ? AppColors.warning : AppColors.teal,
              ),
            ),
            title: Text(
              moment.summary,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              [
                moment.authorName,
                relativeTime(moment.publishedAt, lang),
              ].whereType<String>().join(' · '),
            ),
            trailing: onDelete == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
          ),
          if (moment.body != null && moment.body!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(moment.body!, style: const TextStyle(height: 1.6)),
            ),
          if (moment.photos.isNotEmpty) _Photos(photos: moment.photos),
          if (showChildren && moment.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final child in moment.children)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: incident && child.acknowledgedAt != null
                          ? const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.success,
                            )
                          : null,
                      label: Text(child.firstName),
                    ),
                ],
              ),
            ),
          if (incident && onAcknowledge != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: moment.acknowledged
                  ? Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(s.acknowledged),
                      ],
                    )
                  : FilledButton(
                      onPressed: onAcknowledge,
                      child: Text(s.acknowledge),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.photos});

  final List<MomentPhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.length == 1) {
      return GestureDetector(
        onTap: () => _open(context, photos.first),
        child: AspectRatio(
          aspectRatio: photos.first.aspectRatio.clamp(0.75, 1.8),
          child: _image(photos.first.url),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _open(context, photos[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 180,
              child: _image(photos[i].thumbUrl),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, MomentPhoto photo) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: InteractiveViewer(
                child: _image(photo.url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );

  /// Links expire after 30 minutes: a failed load shows a placeholder
  /// (pull to refresh fetches fresh links).
  Widget _image(String url, {BoxFit fit = BoxFit.cover}) => Image.network(
    url,
    fit: fit,
    errorBuilder: (_, _, _) => Container(
      color: const Color(0xFFF0EEE9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.black26,
      ),
    ),
  );
}
