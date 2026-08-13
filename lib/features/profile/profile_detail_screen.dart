import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/media_item.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/whatsapp_repository.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import '../discovery/discovery_providers.dart';
import '../media/media_viewer.dart';
import '../moderation/report_block_sheet.dart';

/// A member's public profile.
///
/// The contact button is the interesting part. It is not a link to a phone
/// number — the number never reaches this device. The flow is:
///
///   1. tap → `POST /api/profile/<username>/contact-request` creates a PENDING
///      request and notifies the owner,
///   2. the owner accepts or declines in their own inbox,
///   3. once accepted, `GET /api/profile/<username>/whatsapp` answers with a
///      redirect the app can open.
///
/// Every state below is read back from the server. The button never assumes it
/// succeeded, because the gate is the server's to hold.
class ProfileDetailScreen extends ConsumerStatefulWidget {
  const ProfileDetailScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<ProfileDetailScreen> createState() =>
      _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen> {
  String? _contactStatus;
  bool _contactBusy = false;

  Future<void> _requestContact(ProfileSummary profile) async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isSignedIn) {
      final redirect = Uri.encodeComponent(
        AppRoutes.profileFor(widget.username),
      );
      if (mounted) context.push('${AppRoutes.login}?redirect=$redirect');
      return;
    }

    final note = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ContactNoteSheet(displayName: profile.displayName),
    );
    if (note == null) return; // Cancelled.

    setState(() => _contactBusy = true);
    try {
      final status = await ref
          .read(contactRepositoryProvider)
          .requestContact(widget.username, message: note.isEmpty ? null : note);
      if (!mounted) return;
      setState(() => _contactStatus = status);
      _showSnack(
        status == 'ACCEPTED'
            ? 'You can now open WhatsApp with ${profile.displayName}.'
            : status == 'DECLINED'
            ? '${profile.displayName} declined this request.'
            : 'Request sent. ${profile.displayName} will be notified.',
      );
    } on ApiException catch (error) {
      if (mounted) _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _contactBusy = false);
    }
  }

  Future<void> _openWhatsApp() async {
    setState(() => _contactBusy = true);
    try {
      final link = await ref
          .read(whatsAppRepositoryProvider)
          .resolveChatLink(widget.username);

      // Try the installed app first, then the web link. The second call is not
      // a retry of a failure — `wa.me` is a legitimate destination when
      // WhatsApp is not installed.
      final opened = await LegalLinks.openExternal(
        WhatsAppRepository.toAppScheme(link),
      );
      if (!opened) await LegalLinks.openExternal(link);
    } on ApiException catch (error) {
      if (mounted) _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _contactBusy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileByUsernameProvider(widget.username));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: async.when(
        loading: () => const _ProfileSkeleton(),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            error: error,
            onRetry: () =>
                ref.invalidate(profileByUsernameProvider(widget.username)),
          ),
        ),
        data: (profile) {
          if (profile == null) return const _ProfileNotFound();
          return _buildProfile(profile);
        },
      ),
    );
  }

  Widget _buildProfile(ProfileSummary profile) {
    final photos = profile.photos;
    final videos = profile.videos;
    final isTablet = Responsive.of(context).isTablet;
    final heroHeight = isTablet
        ? 460.0
        : MediaQuery.sizeOf(context).width * 1.15;

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          expandedHeight: heroHeight,
          backgroundColor: AppColors.bgSecondary,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: const _CircularBackButton(),
          actions: <Widget>[
            IconButton(
              icon: const _CircularIcon(icon: Icons.more_horiz_rounded),
              tooltip: 'More options',
              onPressed: () => showReportBlockSheet(
                context: context,
                ref: ref,
                userId: profile.id,
                displayName: profile.displayName,
                onBlocked: () {
                  ref.invalidate(browseProvider);
                  if (mounted && context.canPop()) context.pop();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _PhotoCarousel(photos: photos, profile: profile),
          ),
        ),

        SliverToBoxAdapter(
          child: ContentContainer(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  profile.age == null
                                      ? profile.displayName
                                      : '${profile.displayName}, ${profile.age}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall,
                                ),
                              ),
                              if (profile.isVerified) ...<Widget>[
                                const SizedBox(width: AppSpacing.sm),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 22,
                                  color: AppColors.badgeVerifiedFg,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${profile.username}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    if (profile.isVerified) const AppBadge.verified(),
                    if (profile.isAvailableToday)
                      const AppBadge.availableToday(),
                    if (profile.isRedHot) const AppBadge.boosted(),
                    if (profile.placeLabel != null)
                      AppBadge.location(label: profile.placeLabel!),
                  ],
                ),

                if (profile.tagline != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '“${profile.tagline}”',
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFamily,
                      fontSize: 18,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMain,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                _ContactSection(
                  profile: profile,
                  status: _contactStatus,
                  busy: _contactBusy,
                  onRequest: () => _requestContact(profile),
                  onOpenWhatsApp: _openWhatsApp,
                ),

                if (profile.bio != null &&
                    profile.bio!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionTitle(title: 'About ${profile.displayName}'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    profile.bio!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],

                if (profile.dateTypes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  const _SectionTitle(title: 'Date ideas'),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final type in profile.dateTypes)
                        Chip(label: Text(type)),
                    ],
                  ),
                ],

                ..._buildDetails(profile),

                if (videos.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  const _SectionTitle(title: 'Videos'),
                  const SizedBox(height: AppSpacing.md),
                  _VideoRail(videos: videos),
                ],

                if (photos.length > 1) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  const _SectionTitle(title: 'Gallery'),
                  const SizedBox(height: AppSpacing.md),
                  _PhotoGrid(photos: photos, name: profile.displayName),
                ],

                const SizedBox(height: AppSpacing.xxl),
                const _SafetyFooter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDetails(ProfileSummary profile) {
    final rows = <(IconData, String, String)>[
      if (profile.relationshipIntent != null)
        (
          Icons.favorite_outline_rounded,
          'Looking for',
          profile.relationshipIntent!.label,
        ),
      if (profile.height != null)
        (Icons.height_rounded, 'Height', profile.height!),
      if (profile.ethnicity != null)
        (Icons.person_outline_rounded, 'Ethnicity', profile.ethnicity!),
      if (profile.placeLabel != null)
        (Icons.place_outlined, 'Location', profile.placeLabel!),
    ];

    if (rows.isEmpty) return const <Widget>[];

    return <Widget>[
      const SizedBox(height: AppSpacing.xxl),
      const _SectionTitle(title: 'Details'),
      const SizedBox(height: AppSpacing.sm),
      Container(
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: Icon(rows[i].$1, size: 20),
                title: Text(
                  rows[i].$2,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                subtitle: Text(
                  rows[i].$3,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

class _ContactSection extends ConsumerWidget {
  const _ContactSection({
    required this.profile,
    required this.status,
    required this.busy,
    required this.onRequest,
    required this.onOpenWhatsApp,
  });

  final ProfileSummary profile;
  final String? status;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onOpenWhatsApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );

    return switch (status) {
      'ACCEPTED' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GradientButton(
            label: 'Open WhatsApp',
            icon: Icons.chat_rounded,
            isLoading: busy,
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF25D366), Color(0xFF128C7E)],
            ),
            onPressed: onOpenWhatsApp,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${profile.displayName} accepted your request.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      'PENDING' => _ContactStatusCard(
        icon: Icons.hourglass_top_rounded,
        background: AppColors.badgeGoldBg,
        border: AppColors.badgeGoldBorder,
        foreground: AppColors.badgeGoldFg,
        title: 'Request sent',
        message:
            '${profile.displayName} has been notified. You will hear '
            'back in your notifications.',
      ),
      'DECLINED' => _ContactStatusCard(
        icon: Icons.do_not_disturb_on_outlined,
        background: AppColors.bgMuted,
        border: AppColors.border,
        foreground: AppColors.textSecondary,
        title: 'Request declined',
        message:
            '${profile.displayName} decided not to share contact. '
            'Please respect that.',
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GradientButton(
            label: signedIn ? 'Request contact' : 'Sign in to request contact',
            icon: Icons.waving_hand_rounded,
            isLoading: busy,
            onPressed: onRequest,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "${profile.displayName}'s number is never shown here. You ask, "
            'and they decide.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    };
  }
}

class _ContactStatusCard extends StatelessWidget {
  const _ContactStatusCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.sansFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactNoteSheet extends StatefulWidget {
  const _ContactNoteSheet({required this.displayName});

  final String displayName;

  @override
  State<_ContactNoteSheet> createState() => _ContactNoteSheetState();
}

class _ContactNoteSheetState extends State<_ContactNoteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Ask ${widget.displayName} to connect',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'They will see your profile and this note, then decide whether '
                'to share their WhatsApp.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _controller,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Add a note (optional)',
                  hintText: 'Say hello and why you would like to chat.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              GradientButton(
                label: 'Send request',
                icon: Icons.send_rounded,
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos, required this.profile});

  final List<MediaItem> photos;
  final ProfileSummary profile;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return ProfileImage(
        url: null,
        fallbackInitial: widget.profile.displayName,
        borderRadius: BorderRadius.zero,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => openMediaViewer(
              context,
              items: widget.photos,
              initialIndex: index,
              title: widget.profile.displayName,
            ),
            child: ProfileImage(
              url: widget.photos[index].url,
              fallbackInitial: widget.profile.displayName,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        // Scrim under the app bar controls so they stay legible on a light photo.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x66141216), Colors.transparent],
                stops: <double>[0, 0.28],
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: AppSpacing.lg,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < widget.photos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.name});

  final List<MediaItem> photos;
  final String name;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => openMediaViewer(
          context,
          items: photos,
          initialIndex: index,
          title: name,
        ),
        child: ProfileImage(
          url: photos[index].url,
          fallbackInitial: name,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

class _VideoRail extends StatelessWidget {
  const _VideoRail({required this.videos});

  final List<MediaItem> videos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: videos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => openMediaViewer(
            context,
            items: videos,
            initialIndex: index,
            title: 'Video',
          ),
          child: Container(
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.headlineSmall);
}

class _SafetyFooter extends StatelessWidget {
  const _SafetyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.health_and_safety_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Meet in public for a first date, tell someone where you are '
              'going, and report anything that feels wrong. Photos here have '
              'been reviewed by a moderator.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNotFound extends StatelessWidget {
  const _ProfileNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.person_off_outlined,
        title: 'Profile unavailable',
        message: 'This profile does not exist, or it is no longer public.',
        actionLabel: 'Browse members',
        onAction: () => context.go(AppRoutes.discover),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Skeleton(
          height: MediaQuery.sizeOf(context).width * 1.1,
          borderRadius: 0,
        ),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Skeleton(width: 200, height: 28),
              SizedBox(height: AppSpacing.md),
              Skeleton(width: 120, height: 16),
              SizedBox(height: AppSpacing.xl),
              Skeleton(height: 48, borderRadius: AppRadius.pill),
              SizedBox(height: AppSpacing.xl),
              Skeleton(height: 14),
              SizedBox(height: AppSpacing.sm),
              Skeleton(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircularBackButton extends StatelessWidget {
  const _CircularBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const _CircularIcon(icon: Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.discover);
        }
      },
    );
  }
}

class _CircularIcon extends StatelessWidget {
  const _CircularIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 19, color: Colors.white),
    );
  }
}
