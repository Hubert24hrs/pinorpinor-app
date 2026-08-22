import 'package:flutter/material.dart';

import '../../core/constants/primary_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/presence.dart';

/// The member's one primary service, as a badge.
///
/// Mirrors `components/profile/PrimaryServiceBadge.tsx`. The colours come from
/// the catalogue rather than from here, so the card, the picker and the profile
/// screen cannot drift apart — the website holds `badgeClass` on each entry for
/// exactly that reason.
///
/// Renders **nothing** for a null or unrecognised id. A member who registered
/// before 2026-08-21 has not chosen one, and substituting a default would
/// publish a claim on a real person's profile that they never made.
class PrimaryServiceBadge extends StatelessWidget {
  const PrimaryServiceBadge({super.key, required this.id, this.dense = false});

  final String? id;

  /// Tighter padding for the card overlay, where vertical space is the
  /// photograph.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final PrimaryServiceOption? option = primaryServiceFor(id);
    if (option == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: option.badgeBg,
        border: Border.all(color: option.badgeBorder),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(option.glyph, style: TextStyle(fontSize: dense ? 10 : 12)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.sansFamily,
                fontSize: dense ? 10.5 : 12,
                fontWeight: FontWeight.w700,
                color: option.badgeFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The presence dot: 8px, and never a label.
///
/// Draws nothing for null (the member switched presence off) and nothing for
/// [Presence.away], matching the website's card. The distinction between those
/// two is preserved upstream in the model even though both render the same,
/// because only one of them is ours to say.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.presence});

  final Presence? presence;

  @override
  Widget build(BuildContext context) {
    final Presence? p = presence;
    if (p == null || !p.showsDot) return const SizedBox.shrink();

    return Semantics(
      label: p.label,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: p.dotColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
    );
  }
}
