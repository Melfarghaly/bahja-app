import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/media_image.dart';
import '../../core/models/moment.dart';

/// One item of a moment's gallery (photo or video), in posting order.
sealed class MediaItem {
  const MediaItem();

  String get heroTag;
}

class PhotoItem extends MediaItem {
  const PhotoItem(this.photo);

  final MomentPhoto photo;

  @override
  String get heroTag => 'photo-${photo.id}';
}

class VideoItem extends MediaItem {
  const VideoItem(this.video);

  final MomentVideo video;

  @override
  String get heroTag => 'video-${video.id}';
}

List<MediaItem> mediaOf(Moment moment) => [
  ...moment.photos.map(PhotoItem.new),
  ...moment.videos.map(VideoItem.new),
];

/// Full-screen viewer: swipe between photos and videos, pinch to zoom.
/// A video player exists only for the page on screen (and is disposed when
/// it leaves), so a gallery of many clips stays light.
class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.items, this.initial = 0});

  final List<MediaItem> items;
  final int initial;

  static Future<void> open(
    BuildContext context,
    List<MediaItem> items,
    int index,
  ) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => MediaViewer(items: items, initial: index),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _current = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: widget.items.length > 1
          ? Text('${_current + 1} / ${widget.items.length}')
          : null,
    ),
    body: PageView.builder(
      controller: _pages,
      itemCount: widget.items.length,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (context, i) => switch (widget.items[i]) {
        PhotoItem(:final photo) => Hero(
          tag: 'photo-${photo.id}',
          child: InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: MediaImage(
                url: photo.url,
                cacheKey: 'moment-photo-${photo.id}-full',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        VideoItem(:final video) => _VideoPage(
          video: video,
          active: i == _current,
        ),
      },
    ),
  );
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.video, required this.active});

  final MomentVideo video;
  final bool active;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    if (widget.active && _controller == null) _start();
    if (!widget.active) _controller?.pause();
  }

  Future<void> _start() async {
    // Streams with range requests: playback starts before the download ends.
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.url),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (mounted && widget.active) await controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Hero(
      tag: 'video-${widget.video.id}',
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!ready && widget.video.posterUrl != null)
            Center(
              child: AspectRatio(
                aspectRatio: widget.video.aspectRatio,
                child: MediaImage(
                  url: widget.video.posterUrl!,
                  cacheKey: 'moment-video-${widget.video.id}-poster',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (ready)
            GestureDetector(
              onTap: () => setState(
                () => controller.value.isPlaying
                    ? controller.pause()
                    : controller.play(),
              ),
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          if (_failed)
            const Icon(Icons.error_outline, color: Colors.white54, size: 48)
          else if (!ready)
            const CircularProgressIndicator(color: Colors.white)
          else
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, value, _) => IgnorePointer(
                child: AnimatedOpacity(
                  opacity: value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
              ),
            ),
          if (ready)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFFF26A4F),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
