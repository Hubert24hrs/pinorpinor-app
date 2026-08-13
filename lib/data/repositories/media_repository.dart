import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/app_log.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/media_item.dart';

/// Progress for one upload, 0.0–1.0.
typedef UploadProgress = void Function(double value);

/// Direct-to-storage uploads, exactly as the website performs them.
///
/// Three steps, and the split matters:
///
///   1. `POST /api/upload/presigned-url` — the server validates MIME type, size
///      and the per-member cap, then **generates the storage key itself** and
///      returns a short-lived signed URL. The client never chooses the path.
///   2. `PUT` the bytes straight to Supabase Storage using that URL. No file
///      passes through the app server, and the app holds no storage credential
///      of any kind — the signed URL is the entire authority, and it expires.
///   3. `POST /api/upload/confirm` — the server re-checks that the key sits
///      inside the caller's own folder (`isOwnStorageKey`) and that an object
///      really exists there, then writes the `media` row with
///      `isApproved: false`.
///
/// That last flag is the moderation gate: uploads are held until a moderator
/// releases them through the admin queue. The owner sees their own pending
/// media flagged; nobody else sees it at all. The app says "Awaiting review" for
/// the same reason the website does — a photo that silently fails to appear
/// reads as a bug rather than as moderation.
class MediaRepository {
  MediaRepository(this._api);

  final ApiClient _api;

  /// Uploads one file and returns the created (pending) media row.
  ///
  /// Validation runs client-side first purely to fail fast with a clear message;
  /// the server repeats every check and is the one that decides.
  Future<MediaItem> upload({
    required File file,
    required MediaType mediaType,
    required String mimeType,
    int order = 0,
    UploadProgress? onProgress,
    CancelToken? cancelToken,
  }) async {
    final fileSize = await file.length();
    _validate(mimeType: mimeType, fileSize: fileSize);

    onProgress?.call(0.02);

    // 1 — presign. Also where the per-member limit (6 profile photos, 30
    // gallery, 10 videos) is enforced.
    final presigned = await _api.postJson(
      '/api/upload/presigned-url',
      body: <String, dynamic>{
        'mimeType': mimeType,
        'fileSize': fileSize,
        'mediaType': mediaType.wire,
      },
    );

    final signedUrl = asString(presigned['signedUrl']);
    final storageKey = asString(presigned['storageKey']);
    if (signedUrl.isEmpty || storageKey.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.server,
        message: 'Could not start the upload. Please try again.',
      );
    }

    onProgress?.call(0.08);

    // 2 — bytes to storage. A separate Dio instance: this request must not
    // carry the session cookie to a third-party host, and the signed URL is
    // absolute so the API base URL would be wrong for it anyway.
    await _putToStorage(
      signedUrl: signedUrl,
      file: file,
      mimeType: mimeType,
      fileSize: fileSize,
      onProgress: (sent) => onProgress?.call(0.08 + sent * 0.8),
      cancelToken: cancelToken,
    );

    onProgress?.call(0.9);

    // 3 — confirm. Returns a freshly signed read URL so a preview can render
    // immediately; the row itself is held for moderation.
    final confirmed = await _api.postJson(
      '/api/upload/confirm',
      body: <String, dynamic>{
        'storageKey': storageKey,
        'mediaType': mediaType.wire,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'order': order,
      },
    );

    onProgress?.call(1);
    return MediaItem.fromJson(asMap(confirmed['media']));
  }

  Future<void> _putToStorage({
    required String signedUrl,
    required File file,
    required String mimeType,
    required int fileSize,
    required void Function(double) onProgress,
    CancelToken? cancelToken,
  }) async {
    final uploader = Dio(
      BaseOptions(
        connectTimeout: AppConfig.connectTimeout,
        // A 50MB video on a slow connection needs far longer than an API call.
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    try {
      await uploader.putUri<void>(
        Uri.parse(signedUrl),
        data: file.openRead(),
        options: Options(
          headers: <String, dynamic>{
            Headers.contentTypeHeader: mimeType,
            Headers.contentLengthHeader: fileSize,
          },
        ),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress(sent / total);
        },
      );
    } on DioException catch (error) {
      AppLog.warn('Storage upload failed: ${error.type.name}');
      throw ApiException(
        kind: error.response == null
            ? ApiErrorKind.network
            : ApiErrorKind.server,
        message:
            'The upload did not finish. Check your connection and try again.',
      );
    } finally {
      uploader.close(force: true);
    }
  }

  /// Removes the object from the bucket **and** the row.
  ///
  /// The server deletes the file first and only drops the row once that
  /// succeeds, so a storage failure can never leave a row pointing at a file
  /// that was meant to be destroyed. Signed URLs stop resolving immediately —
  /// which is the reason the bucket is private rather than public.
  Future<void> delete(String mediaId) async {
    await _api.deleteJson(
      '/api/upload/delete',
      body: <String, String>{'mediaId': mediaId},
    );
  }

  void _validate({required String mimeType, required int fileSize}) {
    final isImage = AppConfig.allowedImageMimeTypes.contains(mimeType);
    final isVideo = AppConfig.allowedVideoMimeTypes.contains(mimeType);

    if (!isImage && !isVideo) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message:
            'That file type is not supported. Use JPG, PNG, WEBP, HEIC, '
            'MP4, MOV or WEBM.',
      );
    }

    final limit = isImage ? AppConfig.maxImageBytes : AppConfig.maxVideoBytes;
    if (fileSize > limit) {
      final limitMb = (limit / 1024 / 1024).round();
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: 'That file is too large. Maximum size: ${limitMb}MB.',
      );
    }

    if (fileSize <= 0) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'That file appears to be empty.',
      );
    }
  }

  /// Maps a file extension to the MIME type the backend accepts.
  ///
  /// `image_picker` does not always report one, and the server matches on an
  /// exact string — `image/jpg` and `image/jpeg` are both on its list, but
  /// anything outside it is refused.
  static String? mimeTypeForPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    return switch (path.substring(dot + 1).toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => null,
    };
  }
}
