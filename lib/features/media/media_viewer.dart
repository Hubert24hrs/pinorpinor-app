import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';

/// Opens the full-screen media viewer.
void openMediaViewer(
  BuildContext context, {
  required List<MediaItem> items,
  required int initialIndex,
  String? title,
}) {
  if (items.isEmpty) return;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: MediaViewer(
          items: items,
          initialIndex: initialIndex.clamp(0, items.length - 1),
          title: title,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 200),
    ),
  );
}

/// Full-screen photo and video viewer.
///
/// Photos support pinch-zoom; videos stream from the same short-lived signed URL
/// the API issued. There is deliberately **no download or share affordance**:
/// these are members' personal photos on a platform whose whole promise is
/// controlled exposure, and a one-tap save would quietly break that.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.title,
  });

  final List<MediaItem> items;
  final int initialIndex;
  final String? title;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            widget.items.length > 1
                ? '${_index + 1} of ${widget.items.length}'
                : (widget.title ?? ''),
            style: const TextStyle(
              fontFamily: AppTheme.sansFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: PageView.builder(
          controller: _controller,
          itemCount: widget.items.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            if (item.isVideo) {
              return _VideoPlayerView(key: ValueKey(item.id), item: item);
            }
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: ProfileImage(
                  url: item.url,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VideoPlayerView extends StatefulWidget {
  const _VideoPlayerView({super.key, required this.item});

  final MediaItem item;

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    if (!widget.item.hasUrl) {
      setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.item.url),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } on Exception {
      // A signed URL can expire between listing and playback; say so plainly
      // rather than showing a black rectangle forever.
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'This video could not be played. Try reopening the profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.sansFamily,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) return const LoadingView();

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            VideoPlayer(controller),
            GestureDetector(
              onTap: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.rose,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
