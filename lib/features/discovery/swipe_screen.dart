import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/profile.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_controller.dart';
import 'swipe_controller.dart';

/// The swipe deck.
///
/// `/api/discover` and `/api/swipe` have been implemented on the backend the
/// whole time — deck building, block filtering in both directions, country
/// scoping, already-swiped exclusion, and mutual-like match creation with its
/// conversation — and nothing called them. This is the surface for that.
///
/// The gesture model follows the usual one: translate with the finger, rotate
/// proportionally to displacement, commit past a threshold, spring back
/// otherwise. Two things are deliberately added on top:
///
///   * **Buttons that do the same thing.** A drag-only interface is unusable
///     with a screen reader, with one hand full, or with a motor impairment.
///     The buttons are the primary control as far as semantics are concerned;
///     the drag is an accelerator.
///   * **Reduced-motion respect.** When the platform asks for it, the card
///     changes without the fling.
class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen>
    with SingleTickerProviderStateMixin {
  /// Horizontal displacement of the top card, in logical pixels.
  double _dragX = 0;
  double _dragY = 0;

  /// Drives the spring-back when a drag is released short of the threshold.
  late final AnimationController _settle =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addListener(() {
        if (!mounted) return;
        setState(() {
          _dragX = _settleFrom.dx * (1 - _settle.value);
          _dragY = _settleFrom.dy * (1 - _settle.value);
        });
      });

  Offset _settleFrom = Offset.zero;

  /// Past this much displacement, releasing commits the swipe.
  static const _commitThreshold = 110.0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _springBack() {
    _settleFrom = Offset(_dragX, _dragY);
    _settle.forward(from: 0);
  }

  void _resetInstantly() {
    _settle.stop();
    setState(() {
      _dragX = 0;
      _dragY = 0;
    });
  }

  Future<void> _commit(void Function() action) async {
    await HapticFeedback.selectionClick();
    _resetInstantly();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(swipeDeckProvider);
    final controller = ref.read(swipeDeckProvider.notifier);
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );

    // A match is a moment worth marking, and it also has somewhere to go —
    // /api/swipe hands back the conversation it created.
    ref.listen<SwipeDeckState>(swipeDeckProvider, (previous, next) {
      final match = next.lastMatch;
      if (match != null && previous?.lastMatch != match) {
        _showMatch(match.conversationId);
      }
      final failure = next.actionError;
      if (failure != null && previous?.actionError != failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure)));
        controller.clearActionError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('For you'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Browse as a grid',
            onPressed: () => context.go(AppRoutes.discover),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: !signedIn
            ? _SignInPrompt()
            : ContentContainer(
                maxWidth: 460,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: _buildBody(deck, controller),
                ),
              ),
      ),
    );
  }

  Widget _buildBody(SwipeDeckState deck, SwipeDeckController controller) {
    if (deck.isLoading) return const LoadingView(label: 'Finding people…');

    if (deck.error != null) {
      return ErrorView(error: deck.error!, onRetry: controller.refresh);
    }

    if (deck.isEmpty) {
      return EmptyView(
        icon: Icons.done_all_rounded,
        title: deck.exhausted ? "That's everyone for now" : 'Nobody here yet',
        message: deck.exhausted
            ? 'You have seen every profile matching your preferences in your '
                  'country. New members appear as their photos clear moderation.'
            : 'No profiles match your filters. Try widening them.',
        actionLabel: 'Browse the full directory',
        onAction: () => context.go(AppRoutes.discover),
      );
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // The card behind, so the deck reads as a stack rather than a
              // single card that blinks between profiles.
              if (deck.next != null)
                Transform.scale(
                  scale: 0.94,
                  child: Transform.translate(
                    offset: const Offset(0, 14),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.6,
                        child: _SwipeCard(profile: deck.next!),
                      ),
                    ),
                  ),
                ),

              if (deck.top != null)
                _buildTopCard(deck.top!, controller, reduceMotion),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        _ActionBar(
          onPass: () => _commit(controller.pass),
          onSuperlike: () => _commit(controller.superlike),
          onLike: () => _commit(controller.like),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Swipe, or use the buttons',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTopCard(
    ProfileSummary profile,
    SwipeDeckController controller,
    bool reduceMotion,
  ) {
    // Rotation proportional to displacement, capped so a long drag does not
    // spin the card past the point of being readable.
    final rotation = (_dragX / 900).clamp(-0.18, 0.18);
    final intent = _dragX.abs() < 40
        ? null
        : (_dragX > 0 ? _SwipeIntent.like : _SwipeIntent.pass);

    final card = _SwipeCard(
      profile: profile,
      intent: intent,
      intentStrength: (_dragX.abs() / _commitThreshold).clamp(0.0, 1.0),
      onTap: () => context.push(AppRoutes.profileFor(profile.username)),
    );

    if (reduceMotion) {
      // No drag affordance at all under reduced motion — the buttons are the
      // whole interface, and a card that cannot be flung should not invite it.
      return card;
    }

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        _settle.stop();
        setState(() {
          _dragX += details.delta.dx;
          _dragY += details.delta.dy * 0.4;
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragX.abs() > _commitThreshold) {
          _commit(_dragX > 0 ? controller.like : controller.pass);
        } else {
          _springBack();
        }
      },
      child: Transform.translate(
        offset: Offset(_dragX, _dragY),
        child: Transform.rotate(angle: rotation, child: card),
      ),
    );
  }

  void _showMatch(String? conversationId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.favorite_rounded,
          size: 36,
          color: AppColors.rose,
        ),
        title: const Text("It's a match"),
        content: const Text(
          'You both liked each other. A conversation is open — say something '
          'they mentioned on their profile.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(swipeDeckProvider.notifier).clearMatch();
            },
            child: const Text('Keep swiping'),
          ),
          if (conversationId != null)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(swipeDeckProvider.notifier).clearMatch();
                context.push(AppRoutes.conversationFor(conversationId));
              },
              child: const Text('Send a message'),
            ),
        ],
      ),
    );
  }
}

enum _SwipeIntent { like, pass }

/// One card. Photo, scrim, name/age, place, badges — the same visual language
/// as [ProfileCard], scaled up for a full-bleed deck.
class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.profile,
    this.intent,
    this.intentStrength = 0,
    this.onTap,
  });

  final ProfileSummary profile;
  final _SwipeIntent? intent;
  final double intentStrength;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ageLabel = profile.age == null ? '' : ', ${profile.age}';

    return Semantics(
      button: onTap != null,
      label:
          '${profile.displayName}$ageLabel'
          '${profile.placeLabel == null ? '' : ', ${profile.placeLabel}'}'
          '${profile.isVerified ? ', verified' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppColors.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ProfileImage(
                    url: profile.primaryPhoto?.url,
                    fallbackInitial: profile.displayName,
                    borderRadius: BorderRadius.zero,
                  ),

                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Color(0x1A141216),
                          Color(0xE6141216),
                        ],
                        stops: <double>[0.45, 0.66, 1],
                      ),
                    ),
                  ),

                  // Direction feedback. Fades in with the drag so the member
                  // knows what releasing will do before they commit.
                  if (intent != null)
                    Positioned(
                      top: AppSpacing.xl,
                      left: intent == _SwipeIntent.like ? AppSpacing.xl : null,
                      right: intent == _SwipeIntent.pass ? AppSpacing.xl : null,
                      child: Opacity(
                        opacity: intentStrength,
                        child: Transform.rotate(
                          angle: intent == _SwipeIntent.like ? -0.22 : 0.22,
                          child: _IntentStamp(intent: intent!),
                        ),
                      ),
                    ),

                  Positioned(
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                    bottom: AppSpacing.xl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            if (profile.isRedHot) const AppBadge.boosted(),
                            if (profile.isFeatured && !profile.isRedHot)
                              const AppBadge.newProfile(),
                            if (profile.isAvailableToday)
                              const AppBadge.availableToday(),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                '${profile.displayName}$ageLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.displayFamily,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (profile.isVerified) ...<Widget>[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                size: 20,
                                color: Color(0xFF6EE7B7),
                              ),
                            ],
                          ],
                        ),
                        if (profile.placeLabel != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.place_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  profile.placeLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.sansFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (profile.tagline != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            profile.tagline!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.sansFamily,
                              fontSize: 13.5,
                              height: 1.45,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntentStamp extends StatelessWidget {
  const _IntentStamp({required this.intent});

  final _SwipeIntent intent;

  @override
  Widget build(BuildContext context) {
    final isLike = intent == _SwipeIntent.like;
    final colour = isLike ? const Color(0xFF10B981) : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colour, width: 3),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: Colors.black.withValues(alpha: 0.25),
      ),
      child: Text(
        isLike ? 'LIKE' : 'PASS',
        style: TextStyle(
          fontFamily: AppTheme.sansFamily,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: colour,
        ),
      ),
    );
  }
}

/// Pass / superlike / like. These are the accessible path to every action the
/// drag performs, and they carry the semantic labels.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onPass,
    required this.onSuperlike,
    required this.onLike,
  });

  final VoidCallback onPass;
  final VoidCallback onSuperlike;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _CircleAction(
          icon: Icons.close_rounded,
          label: 'Pass',
          colour: AppColors.error,
          onPressed: onPass,
        ),
        const SizedBox(width: AppSpacing.xl),
        _CircleAction(
          icon: Icons.star_rounded,
          label: 'Super like',
          colour: AppColors.gold,
          size: 52,
          onPressed: onSuperlike,
        ),
        const SizedBox(width: AppSpacing.xl),
        _CircleAction(
          icon: Icons.favorite_rounded,
          label: 'Like',
          colour: AppColors.rose,
          onPressed: onLike,
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.colour,
    required this.onPressed,
    this.size = 62,
  });

  final IconData icon;
  final String label;
  final Color colour;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Icon(icon, size: size * 0.42, color: colour),
          ),
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.favorite_border_rounded,
      title: 'Sign in to start swiping',
      message:
          'Liking and matching need an account. Browsing the directory does '
          'not — that stays open to everyone.',
      actionLabel: 'Sign in',
      onAction: () => context.push(AppRoutes.login),
    );
  }
}
