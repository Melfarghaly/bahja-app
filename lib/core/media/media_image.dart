import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A wall image that loads once and stays cached.
///
/// Links are signed and change on every fetch, so the cache is keyed by the
/// media id + variant, not the URL: scrolling back, refreshing the feed or
/// reopening the app shows the photo instantly with no new download.
/// Decoded at the size it is shown (not the full 2048px), which keeps long
/// feeds smooth and memory low.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.url,
    required this.cacheKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String url;
  final String cacheKey;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(color: const Color(0xFFF0EEE9));
    final broken = Container(
      color: const Color(0xFFF0EEE9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.black26,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final logicalWidth =
            width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        final decodeWidth = logicalWidth == null
            ? null
            : (logicalWidth * ratio).round();

        if (kIsWeb) {
          // The browser cache handles it on the web.
          return Image.network(
            url,
            fit: fit,
            width: width,
            height: height,
            cacheWidth: decodeWidth,
            errorBuilder: (_, _, _) => broken,
            frameBuilder: (_, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: child,
                  ),
          );
        }

        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: cacheKey,
          fit: fit,
          width: width,
          height: height,
          memCacheWidth: decodeWidth,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => broken,
        );
      },
    );
  }
}
