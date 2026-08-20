import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/media_item.dart';
import '../../data/models/profile.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../media/media_viewer.dart';

/// Member videos — the app's counterpart of the website's `/videos`.
///
/// ## This is an approximation, and the difference is worth knowing
///
/// The website's page is a server component that queries the `media` table
/// directly for the 24 newest `VIDEO` rows platform-wide. **There is no API
/// route behind it**, so the app cannot ask the same question.
///
/// What it does instead is page the public profile feed and collect the videos
/// those profiles carry. The visibility rules are identical, because the same
/// endpoint enforces them — `isApproved`, `isPublic`, and the owner's profile
/// being public, discoverable and not banned. What differs is completeness and
/// ordering: this shows videos belonging to the profiles discovery returns
/// first, not the newest videos on the platform, and `/api/public/profiles`
/// caps media at four items per profile.
///
/// Closing that gap properly needs `GET /api/public/videos` on the website.
/// Recorded in `docs/FEATURE_PARITY.md` rather than papered over here, because
/// a screen that silently shows a subset while implying completeness is the
/// kind of thing nobody notices until a member asks why their video is missing.
class VideosScreen extends ConsumerWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videoFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Videos')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.rose,
          onRefresh: () async => ref.invalidate(videoFeedProvider),
          child: videos.when(
            loading: () => const LoadingView(),
            error: (error, _) => ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.xxxl),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(videoFeedProvider),
                ),
              ],
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xxl),
                    EmptyView(
                      icon: Icons.movie_outlined,
                      title: 'No videos yet',
                      message:
                          'Members have not published any videos in your area '
                          'yet. Photos and profiles are still there to browse.',
                      actionLabel: 'Browse members',
                      onAction: () => context.go(AppRoutes.discover),
                    ),
                  ],
                );
              }

              return ContentContainer(
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.of(context).isCompact ? 2 : 3,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    return _VideoTile(entry: entry);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One video and the member it belongs to.
@immutable
class VideoEntry {
  const VideoEntry({required this.media, required this.owner});

  final MediaItem media;
  final ProfileSummary owner;
}

/// Videos gathered from the public profile feed. See [VideosScreen] for why
/// this is not the same query the website runs.
final videoFeedProvider = FutureProvider.autoDispose<List<VideoEntry>>((
  ref,
) async {
  final page = await ref
      .watch(discoveryRepositoryProvider)
      .browse(limit: 30);

  return <VideoEntry>[
    for (final ProfileSummary profile in page.profiles)
      for (final MediaItem video in profile.videos)
        VideoEntry(media: video, owner: profile),
  ];
});

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.entry});

  final VideoEntry entry;

  @override
  Widget build(BuildContext context) {
    final owner = entry.owner;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => openMediaViewer(
        context,
        items: <MediaItem>[entry.media],
        initialIndex: 0,
        title: owner.displayName,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ProfileImage(
                  url: entry.media.thumbnailUrl ?? entry.media.url,
                  fallbackInitial: owner.displayName,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            owner.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (owner.placeLabel != null)
            Text(
              owner.placeLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
