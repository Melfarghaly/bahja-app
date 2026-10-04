import 'package:flutter/material.dart';

import '../../core/media/media_image.dart';
import '../../core/models/moment.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';
import 'media_viewer.dart';

IconData momentIcon(String type) => switch (type) {
  'photo' => Icons.photo_camera_outlined,
  'video' => Icons.videocam_outlined,
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
          if (moment.photos.isNotEmpty || moment.videos.isNotEmpty)
            _MediaStrip(items: mediaOf(moment)),
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

/// Photos and videos of a moment. One item fills the width at its real
/// aspect ratio (no layout jump while loading); several scroll sideways as
/// thumbnails. Videos show their poster: no player is created in the feed.
class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      final item = items.single;
      final ratio = switch (item) {
        PhotoItem(:final photo) => photo.aspectRatio,
        VideoItem(:final video) => video.aspectRatio,
      };
      return GestureDetector(
        onTap: () => MediaViewer.open(context, items, 0),
        child: AspectRatio(
          aspectRatio: ratio.clamp(0.75, 1.8),
          child: _Thumb(item: item, large: true),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => MediaViewer.open(context, items, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 180,
              child: _Thumb(item: items[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, this.large = false});

  final MediaItem item;
  final bool large;

  @override
  Widget build(BuildContext context) => Hero(
    tag: item.heroTag,
    child: switch (item) {
      // A single photo shows the full image; a strip only needs thumbnails.
      PhotoItem(:final photo) => MediaImage(
        url: large || photo.thumbUrl == null ? photo.url : photo.thumbUrl!,
        cacheKey: large || photo.thumbUrl == null
            ? 'moment-photo-${photo.id}-full'
            : 'moment-photo-${photo.id}-thumb',
      ),
      VideoItem(:final video) => Stack(
        fit: StackFit.expand,
        children: [
          if (video.posterUrl != null)
            MediaImage(
              url: video.posterUrl!,
              cacheKey: 'moment-video-${video.id}-poster',
            )
          else
            Container(color: Colors.black87),
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
          ),
          if (video.durationMs != null)
            PositionedDirectional(
              end: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  video.durationLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    },
  );
}
