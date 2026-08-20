import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/navigation.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';

/// A section the platform advertises but has not built — the app's counterpart
/// of the website's `SectionPlaceholder`.
///
/// **These are not app gaps.** Feeds, Events, Rooms, Adverts and Testimonials
/// do not exist on the website either; it ships the same explanatory page for
/// each. The menu entry is kept, and this screen shown, because the alternative
/// is worse in both directions: hiding the entry makes the app look like it is
/// missing something the website has, and inventing content would mean
/// publishing posts, events or testimonials that nobody wrote.
///
/// The Events copy says why that matters most sharply — a fabricated event is
/// a date and a place nobody is actually holding, which on this platform could
/// put someone in a room alone with a stranger.
///
/// The wording is taken verbatim from the website so a member never gets two
/// different explanations for the same absence.
class SectionPlaceholderScreen extends StatelessWidget {
  const SectionPlaceholderScreen({super.key, required this.copy});

  final SectionPlaceholderCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(copy.title)),
      body: SafeArea(
        child: ContentContainer(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 28,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                copy.intro,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),

              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Why this is empty',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(copy.status, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.discover),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Browse members instead'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
