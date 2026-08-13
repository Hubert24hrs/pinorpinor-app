import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/app_log.dart';
import '../../data/repositories/media_repository.dart';

/// A file chosen by the member, ready to upload.
class PickedMedia {
  const PickedMedia({
    required this.file,
    required this.mimeType,
    required this.sizeBytes,
  });

  final File file;
  final String mimeType;
  final int sizeBytes;
}

/// Picking and preparing media.
///
/// Compression is not cosmetic here. A modern phone camera produces 4–8MB JPEGs,
/// and members on Nigerian mobile data pay for every one of those bytes. Images
/// are re-encoded to a long edge of 1920 at quality 82 — comfortably above what
/// a profile card or full-screen view needs, and typically a 60–80% reduction.
///
/// **Video is not re-encoded.** Doing it properly needs a platform transcoder,
/// and a bad job would degrade the member's video for no gain. Instead the 50MB
/// server limit is checked before upload so an oversized file is rejected with a
/// clear message rather than failing halfway through the transfer.
class MediaPickerService {
  const MediaPickerService();

  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery or camera, then compresses it.
  ///
  /// Permissions are requested by `image_picker` at the moment of use, which is
  /// the contextual prompt both stores expect — the app asks for the camera
  /// when the member taps "Take a photo", never at launch.
  Future<PickedMedia?> pickImage({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      // A first-pass cap at the picker level; the real work is done below.
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (picked == null) return null;

    final original = File(picked.path);
    final mimeType =
        MediaRepository.mimeTypeForPath(picked.path) ??
        MediaRepository.mimeTypeForPath(picked.name) ??
        'image/jpeg';

    if (!AppConfig.allowedImageMimeTypes.contains(mimeType)) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message:
            'That image format is not supported. Use JPG, PNG, WEBP or '
            'HEIC.',
      );
    }

    final compressed = await _compressImage(original);
    final file = compressed ?? original;
    final size = await file.length();

    if (size > AppConfig.maxImageBytes) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message:
            'That image is still larger than '
            '${(AppConfig.maxImageBytes / 1024 / 1024).round()}MB after '
            'compression. Try a different photo.',
      );
    }

    return PickedMedia(
      file: file,
      // HEIC is transcoded to JPEG by the compressor, so report what was
      // actually written rather than what came out of the picker.
      mimeType: compressed != null ? 'image/jpeg' : mimeType,
      sizeBytes: size,
    );
  }

  Future<PickedMedia?> pickVideo({required ImageSource source}) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
    if (picked == null) return null;

    final file = File(picked.path);
    final mimeType =
        MediaRepository.mimeTypeForPath(picked.path) ?? 'video/mp4';

    if (!AppConfig.allowedVideoMimeTypes.contains(mimeType)) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'That video format is not supported. Use MP4, MOV or WEBM.',
      );
    }

    final size = await file.length();
    if (size > AppConfig.maxVideoBytes) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message:
            'Videos must be under '
            '${(AppConfig.maxVideoBytes / 1024 / 1024).round()}MB. '
            'Try a shorter clip.',
      );
    }

    return PickedMedia(file: file, mimeType: mimeType, sizeBytes: size);
  }

  /// Returns the compressed file, or null if compression was not possible —
  /// in which case the caller uses the original rather than failing.
  Future<File?> _compressImage(File source) async {
    try {
      final directory = await getTemporaryDirectory();
      final target =
          '${directory.path}/pnp_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        target,
        quality: 82,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
        // Strips EXIF as a side effect of re-encoding — which also removes any
        // GPS coordinates the camera embedded. On a platform where members post
        // personal photos, shipping their home location inside a JPEG would be
        // a far worse leak than anything the API exposes.
        keepExif: false,
      );

      if (result == null) return null;
      return File(result.path);
    } on Exception catch (error) {
      AppLog.warn('Image compression failed, using original: $error');
      return null;
    }
  }
}
