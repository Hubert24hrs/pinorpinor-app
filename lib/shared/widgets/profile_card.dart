import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/profile.dart';
import 'primary_service_badge.dart';
import 'profile_image.dart';
import 'states.dart';

/// The shared profile card, matching `components/profile/ProfileCard.tsx`.
///
/// A tall photo with a charcoal gradient scrim and everything else in the strip
/// along the bottom. The website's `.tilt-card` hover is replaced with a
/// press-scale, which is the mobile equivalent of the same idea — and it is
/// suppressed when the platform asks for reduced motion.
///
/// ## Nothing is drawn over the top of the photograph. Deliberately.
///
/// Four badges used to sit in the top corner: online, red hot, new and available
/// today. On a 3:4 portrait they landed across the member's face, which is the
/// one thing a member card exists to show. The website removed its own two on
/// 2026-08-21 for exactly that reason and this card follows, because the two
/// grids show the same members to the same people.
///
/// Presence became the 8px dot beside her name, which says the same thing in a
/// twentieth of the space. "Available today" moved into the meta line. The boost
/// and new-profile badges are gone rather than moved: a boost buys **placement**,
/// which the member still gets, and neither badge told a visitor anything they
/// could act on.
///
/// **If something new needs to go on this card, it goes in the bottom strip. If
/// it genuinely cannot, it is probably not worth covering a face for.**
class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.onContact,
    this.aspectRatio = 3 / 4,
  });

  final ProfileSummary profile;
  final VoidCallback? onTap;

  /// Tapping the WhatsApp glyph. Defaults to [onTap], which opens the profile.
  ///
  /// It must never dial anybody. The member's number is not in this payload and
  /// must never be: a direct link here would publish every member's WhatsApp
  /// number to anonymous visitors and let a whole grid be harvested in one pass.
  /// The destination is the consent gate on her profile, which the backend
  /// re-checks on every call — so this is a signpost, not a permission.
  final VoidCallback? onContact;

  final double aspectRatio;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = (_pressed && !reduceMotion) ? 0.975 : 1.0;

    final ageLabel = profile.age == null ? '' : ', ${profile.age}';

    return Semantics(
      button: widget.onTap != null,
      label:
          '${profile.displayName}$ageLabel'
          '${profile.primaryServiceOption == null ? '' : ', ${profile.primaryServiceOption!.label}'}'
          '${profile.placeLabel == null ? '' : ', ${profile.placeLabel}'}'
          '${profile.isVerified ? ', verified' : ''}'
          '${profile.presence == null || !profile.presence!.showsDot ? '' : ', ${profile.presence!.label}'}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppColors.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ProfileImage(
                        url: profile.primaryPhoto?.url,
                        fallbackInitial: profile.displayName,
                        borderRadius: BorderRadius.zero,
                      ),
                      // Scrim: without it, white text over a pale photo becomes
                      // unreadable — a real failure on user-supplied images.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Color(0x1A141216),
                              Color(0xD9141216),
                            ],
                            stops: <double>[0.42, 0.64, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        bottom: AppSpacing.md,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Its own line, and ONLY when there is one. An
                            // empty row still costs about 20px, which on a
                            // two-up 320px grid pushes the text block that
                            // much further up the photograph for every member
                            // who has not chosen yet -- the opposite of the
                            // point of this change.
                            if (profile.primaryService != null) ...<Widget>[
                              PrimaryServiceBadge(
                                id: profile.primaryService,
                                dense: true,
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: <Widget>[
                                // Expanded rather than Flexible beside a
                                // Spacer: two flexible children would split the
                                // width evenly and truncate every short name at
                                // the halfway point.
                                Expanded(
                                  child: Row(
                                    children: <Widget>[
                                      // Presence, moved here from the pill that
                                      // used to sit over her face.
                                      PresenceDot(presence: profile.presence),
                                      Flexible(
                                        child: Text(
                                          '${profile.displayName}$ageLabel',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: AppTheme.displayFamily,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      // Kept where the website dropped its own
                                      // "Verified Woman" pill, because the
                                      // objection does not apply: that pill
                                      // printed regardless of
                                      // verificationStatus and was simply
                                      // untrue on an unverified account. This
                                      // is conditional, small, and nowhere near
                                      // her face.
                                      if (profile.isVerified) ...<Widget>[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.verified_rounded,
                                          size: 15,
                                          color: Color(0xFF6EE7B7),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                _WhatsAppGlyph(
                                  onTap: widget.onContact ?? widget.onTap,
                                  memberName: profile.displayName,
                                ),
                              ],
                            ),
                            if (profile.placeLabel != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.place_rounded,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      profile.placeLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.sansFamily,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (profile.isAvailableToday) ...<Widget>[
                              const SizedBox(height: 2),
                              const Text(
                                'Available today',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.sansFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6EE7B7),
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
        ),
      ),
    );
  }
}

/// The card's loading state, sized to match so the grid does not reflow when
/// real data arrives.
class ProfileCardSkeleton extends StatelessWidget {
  const ProfileCardSkeleton({super.key, this.aspectRatio = 3 / 4});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: const Skeleton(height: double.infinity, borderRadius: AppRadius.lg),
  );
}

/// The WhatsApp mark, in the card's bottom strip.
///
/// Drawn rather than imported so the card carries no asset, and coloured with
/// WhatsApp's own green because a member recognises the shape before they read
/// anything. It opens the profile, where the consent gate lives -- see
/// [ProfileCard.onContact] for why it must never open wa.me.
class _WhatsAppGlyph extends StatelessWidget {
  const _WhatsAppGlyph({required this.onTap, required this.memberName});

  final VoidCallback? onTap;
  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Request WhatsApp contact with $memberName',
      child: GestureDetector(
        onTap: onTap,
        // Behaviour matters here: the card behind this is itself a tap target,
        // and without an opaque hit test the gesture falls through to it.
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF25D366),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chat_rounded, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}
