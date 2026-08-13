import '../../core/config/app_config.dart';
import 'enums.dart';
import 'json.dart';

/// One row of the website's `media` table, as the API returns it.
///
/// `storageKey` is deliberately absent: `signMediaUrls()` strips it from every
/// response, so the client never learns bucket paths. `storageUrl` arrives as a
/// freshly signed read URL with a one-hour life, which is why [signedUrlIssuedAt]
/// exists — a cached image older than that is refetched rather than shown broken.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.mediaType,
    required this.url,
    this.thumbnailUrl,
    this.order = 0,
    this.isApproved = true,
    this.width,
    this.height,
    this.durationSeconds,
    this.issuedAt,
  });

  final String id;
  final MediaType mediaType;

  /// Short-lived signed URL. Empty when the object could not be signed, which
  /// the API represents as "no media" rather than an error.
  final String url;

  final String? thumbnailUrl;
  final int order;

  /// False while a moderator has not yet released the upload. Only the owner
  /// ever sees this as false — every other read path filters unapproved media
  /// out server-side.
  final bool isApproved;

  final int? width;
  final int? height;
  final double? durationSeconds;
  final DateTime? issuedAt;

  bool get hasUrl => url.isNotEmpty;
  bool get isVideo => mediaType.isVideo;

  /// A stable URL that outlives the signature, for the rare place that needs
  /// one (an avatar held across a long session). Mirrors `/api/media/[id]`.
  String get stableUrl => '${AppConfig.apiOrigin}/api/media/$id';

  bool get signatureLikelyExpired {
    final issued = issuedAt;
    if (issued == null) return false;
    return DateTime.now().difference(issued) > AppConfig.mediaCacheTtl;
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: asString(json['id']),
      mediaType: MediaType.parse(json['mediaType']),
      url: asString(json['storageUrl']),
      thumbnailUrl: asStringOrNull(json['thumbnailUrl']),
      order: asInt(json['order']),
      isApproved: asBool(json['isApproved'], fallback: true),
      width: asIntOrNull(json['width']),
      height: asIntOrNull(json['height']),
      durationSeconds: asDoubleOrNull(json['duration']),
      issuedAt: DateTime.now(),
    );
  }

  static List<MediaItem> listFrom(Object? value) =>
      asMapList(value).map(MediaItem.fromJson).toList(growable: false);
}
