import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'brand.dart';

/// Shimmering placeholder, matching the website's `.skeleton` utility.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
  });

  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = AppRadius.pill;

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour the platform setting: a looping shimmer is exactly the kind of
    // motion `prefers-reduced-motion` exists for, and the website already
    // suppresses its equivalent.
    if (MediaQuery.disableAnimationsOf(context)) {
      return _staticBlock();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 + 2 * (1 - t), 0),
              colors: const <Color>[
                AppColors.skeletonBase,
                AppColors.skeletonHighlight,
                AppColors.skeletonBase,
              ],
              stops: const <double>[0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }

  Widget _staticBlock() => Container(
    width: widget.width,
    height: widget.height,
    decoration: BoxDecoration(
      color: AppColors.skeletonBase,
      borderRadius: BorderRadius.circular(widget.borderRadius),
    ),
  );
}

/// One consistent error surface for every failed request.
///
/// It reads the [ApiException] rather than a bare string so an offline device,
/// a rate limit and a server fault each get the right words and the right
/// affordance — retry is only offered where retrying could actually help.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final message = api?.message ?? 'Something went wrong. Please try again.';
    final canRetry = onRetry != null && (api?.isRetryable ?? true);

    final icon = switch (api?.kind) {
      ApiErrorKind.network => Icons.wifi_off_rounded,
      ApiErrorKind.rateLimited => Icons.hourglass_top_rounded,
      ApiErrorKind.unauthorized => Icons.lock_outline_rounded,
      ApiErrorKind.accountSuspended => Icons.gpp_bad_outlined,
      ApiErrorKind.notFound => Icons.search_off_rounded,
      _ => Icons.error_outline_rounded,
    };

    return Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: compact ? 32 : 44, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (canRetry) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The "nothing here yet" surface. Always says what would fill it and, where
/// there is one, offers the action that would.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.badgeRoseBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.badgeRoseBorder),
              ),
              child: Icon(icon, size: 30, color: AppColors.rose),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              GradientButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A thin banner pinned under the app bar while the device has no connection.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: visible
          ? Container(
              width: double.infinity,
              color: AppColors.charcoal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    "You're offline — showing what was loaded",
                    style: TextStyle(
                      fontFamily: AppTheme.sansFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Centre-of-screen spinner, for the handful of places a skeleton would be
/// more noise than signal.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
