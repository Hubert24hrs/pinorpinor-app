import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'states.dart';

/// A member photo, cached with a graceful failure.
///
/// Media URLs from the API are **signed and expire after an hour**, which makes
/// naive caching actively wrong: a cached image can outlive its signature, and a
/// deleted photo must stop rendering immediately rather than lingering. The
/// cache key is therefore the URL's storage path without its signature query,
/// so re-signing the same object reuses the cached bytes while a *different*
/// object never collides — and `cacheManager`'s own TTL bounds how long a
/// removed photo can survive.
class ProfileImage extends StatelessWidget {
  const ProfileImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackInitial,
    this.width,
    this.height,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? fallbackInitial;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final source = url;

    Widget content;
    if (source == null || source.isEmpty) {
      content = _Placeholder(initial: fallbackInitial);
    } else {
      content = CachedNetworkImage(
        imageUrl: source,
        cacheKey: cacheKeyFor(source),
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (context, _) =>
            const Skeleton(height: double.infinity, borderRadius: 0),
        errorWidget: (context, _, _) => _Placeholder(initial: fallbackInitial),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: width, height: height, child: content),
    );
  }

  /// Strips the signature so the same object caches once across re-signings.
  ///
  /// Supabase signs with a `token` query parameter; the path identifies the
  /// object. Anything unparseable falls back to the whole URL, which is
  /// correct-but-wasteful rather than wrong.
  static String cacheKeyFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return '${uri.host}${uri.path}';
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.initial});

  final String? initial;

  @override
  Widget build(BuildContext context) {
    final letter = (initial ?? '').trim();
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.roseGradient),
      child: Center(
        child: letter.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
            : Text(
                letter.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppTheme.displayFamily,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// Circular avatar built on [ProfileImage].
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.url,
    this.size = 44,
    this.initial,
    this.isVerified = false,
  });

  final String? url;
  final double size;
  final String? initial;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final image = ProfileImage(
      url: url,
      width: size,
      height: size,
      fallbackInitial: initial,
      borderRadius: BorderRadius.circular(size),
    );

    if (!isVerified) return image;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          image,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                size: size * 0.32,
                color: AppColors.badgeVerifiedFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
