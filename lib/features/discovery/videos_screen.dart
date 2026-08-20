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

/// How many profile pages to sweep for videos.
///
/// Videos are sparse — most members post photos only — so one page of profiles
/// usually yields almost nothing. Three is a deliberate compromise: enough that
/// the screen has content on a real platform, few enough that opening it is
/// three requests rather than an unbounded crawl.
const int _kVideoSweepPages = 3;

/// Videos gathered from the public profile feed.
///
/// **This cannot be made exact from the client, and that is a property of the
/// API rather than a shortcut.** `/api/public/profiles` selects only
/// `id`, `storageKey`, `storageUrl` and `mediaType` for media, caps it at four
/// items per profile, and orders by `order` — so there is **no timestamp to
/// sort by**. "The 24 newest videos on the platform", which is what the website
/// renders, is not expressible here at any effort.
///
/// What this does instead is sweep the first few pages of discovery and collect
/// what they carry. Visibility is identical, because the same endpoint applies
/// the same rules. Ordering and completeness are not.
final videoFeedProvider = FutureProvider.autoDispose<List<VideoEntry>>((
  ref,
) async {
  final repository = ref.watch(discoveryRepositoryProvider);
  final entries = <VideoEntry>[];
  final seen = <String>{};

  for (int page = 1; page <= _kVideoSweepPages; page++) {
    final result = await repository.browse(page: page, limit: 30);

    for (final ProfileSummary profile in result.profiles) {
      for (final MediaItem video in profile.videos) {
        // A profile can surface on more than one page while the feed shifts
        // under paging; de-duplicate on the media id so nothing renders twice.
        if (seen.add(video.id)) {
          entries.add(VideoEntry(media: video, owner: profile));
        }
      }
    }

    if (page >= result.totalPages) break;
  }

  return entries;
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
