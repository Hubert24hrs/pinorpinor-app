/// The building blocks the website's editorial pages are made of.
///
/// About, Safety, FAQ, Privacy and Terms are five pages on the website built
/// from the same two shapes: a dark hero panel with a gold pill above the
/// heading, and white cards with a hairline border holding the prose. They were
/// the last sections of the platform that opened a browser instead of a screen,
/// which meant a member tapping "Safety & Blacklist" left the app to read the
/// one page they are most likely to need in a hurry.
///
/// These widgets exist so the five screens stay identical to each other and to
/// the site. Anything structural belongs here, not copied five times.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';

/// The dark panel at the top of a content page: gold pill, serif heading, lede.
class ContentHero extends StatelessWidget {
  const ContentHero({
    super.key,
    required this.pill,
    required this.pillIcon,
    required this.title,
    required this.lede,
  });

  final String pill;
  final IconData pillIcon;
  final String title;
  final String lede;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(pillIcon, size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    pill,
                    style: const TextStyle(
                      fontFamily: AppTheme.sansFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.textInverse,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            lede,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textInverse.withValues(alpha: 0.78),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white card with the website's hairline border, holding prose.
class ContentCard extends StatelessWidget {
  const ContentCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// A serif section heading inside a [ContentCard].
class ContentHeading extends StatelessWidget {
  const ContentHeading(this.text, {super.key, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: small
          ? theme.textTheme.titleMedium
          : theme.textTheme.headlineSmall,
    );
  }
}

/// A paragraph, at the line height the website's prose uses.
class ContentBody extends StatelessWidget {
  const ContentBody(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
    );
  }
}

/// A bulleted list. Each entry may carry a bold lead-in, which is how the
/// website writes its pillar lists ("**Privacy First:** Location tracking...").
class ContentBullets extends StatelessWidget {
  const ContentBullets(this.items, {super.key});

  /// `(lead, body)`. A null lead renders a plain bullet.
  final List<(String?, String)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium?.copyWith(height: 1.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (lead, body) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        if (lead != null)
                          TextSpan(
                            text: '$lead ',
                            style: base?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                        TextSpan(text: body, style: base),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One of the Safety page's four numbered pillars.
class ContentPillar extends StatelessWidget {
  const ContentPillar({
    super.key,
    required this.number,
    required this.title,
    required this.body,
    required this.tint,
    required this.tintFg,
  });

  final String number;
  final String title;
  final String body;
  final Color tint;
  final Color tintFg;

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontFamily: AppTheme.sansFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tintFg,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ContentHeading(title, small: true),
        const SizedBox(height: AppSpacing.xs),
        ContentBody(body),
      ],
    );
  }
}

/// A tick-marked guidance tile, as used by "Safe First Meeting Guidance".
class ContentAdvice extends StatelessWidget {
  const ContentAdvice({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2, right: AppSpacing.sm),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The standard page chrome for every content screen.
class ContentScaffold extends StatelessWidget {
  const ContentScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              for (final child in children) ...<Widget>[
                child,
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
