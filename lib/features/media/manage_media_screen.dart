import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/account.dart';
import '../../data/models/enums.dart';
import '../../data/models/media_item.dart';
import '../../shared/widgets/profile_image.dart';
import '../../shared/widgets/states.dart';
import '../auth/login_screen.dart';
import '../profile/account_providers.dart';
import 'media_picker_service.dart';
import 'media_viewer.dart';

/// Photo and video management.
///
/// Two facts drive the whole screen:
///
///   * **Only lady accounts can upload.** `/api/upload/presigned-url` returns
///     403 for anyone else, so this screen shows an explanation rather than
///     controls that would fail.
///   * **Every upload is held for moderation.** `isApproved` defaults to false
///     and only the admin queue can flip it. The owner sees their own pending
///     media flagged "Awaiting review" — hiding it would make a photo appear to
///     vanish seconds after uploading, which reads as a bug rather than as the
///     review the product promises.
class ManageMediaScreen extends ConsumerStatefulWidget {
  const ManageMediaScreen({super.key});

  @override
  ConsumerState<ManageMediaScreen> createState() => _ManageMediaScreenState();
}

class _ManageMediaScreenState extends ConsumerState<ManageMediaScreen> {
  static const _picker = MediaPickerService();

  double? _uploadProgress;
  String? _error;

  Future<void> _addMedia(MediaType type, Account account) async {
    final limit = switch (type) {
      MediaType.profilePhoto => AppConfig.maxProfilePhotos,
      MediaType.galleryPhoto => AppConfig.maxGalleryPhotos,
      MediaType.video => AppConfig.maxVideos,
      _ => 0,
    };
    final existing = switch (type) {
      MediaType.profilePhoto => account.profilePhotos.length,
      MediaType.galleryPhoto => account.galleryPhotos.length,
      MediaType.video => account.videos.length,
      _ => 0,
    };

    if (existing >= limit) {
      setState(
        () => _error =
            'You have reached the limit of $limit for this section. Remove one '
            'first.',
      );
      return;
    }

    final source = await _chooseSource(isVideo: type.isVideo);
    if (source == null) return;

    setState(() {
      _error = null;
      _uploadProgress = 0;
    });

    try {
      final picked = type.isVideo
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source);

      if (picked == null) {
        setState(() => _uploadProgress = null);
        return;
      }

      await ref
          .read(mediaRepositoryProvider)
          .upload(
            file: picked.file,
            mediaType: type,
            mimeType: picked.mimeType,
            order: existing,
            onProgress: (value) {
              if (mounted) setState(() => _uploadProgress = value);
            },
          );

      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploaded. A moderator will review it shortly.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  Future<ImageSource?> _chooseSource({required bool isVideo}) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(isVideo ? 'Choose a video' : 'Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(isVideo ? 'Record a video' : 'Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(MediaItem item) async {
    // Captured before the await so the analyzer can see the context is not
    // reused across the gap.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this file?'),
        content: const Text(
          'It is deleted from storage immediately and stops loading for '
          'everyone. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(mediaRepositoryProvider).delete(item.id);
      ref.invalidate(myProfileProvider);
      messenger.showSnackBar(const SnackBar(content: Text('File removed.')));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Photos and videos')),
      body: SafeArea(
        child: account.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          data: (data) {
            if (!data.canUploadMedia) return const _UploadNotAvailable();
            return _buildManager(data);
          },
        ),
      ),
    );
  }

  Widget _buildManager(Account account) {
    return ContentContainer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          if (_uploadProgress != null) ...<Widget>[
            _UploadProgress(value: _uploadProgress!),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_error != null) ...<Widget>[
            InlineNotice.error(message: _error!),
            const SizedBox(height: AppSpacing.lg),
          ],

          const InlineNotice.info(
            message:
                'Every photo and video is checked by a moderator before '
                'other members can see it. Yours stay visible to you in the '
                'meantime, marked "Awaiting review".',
          ),
          const SizedBox(height: AppSpacing.xl),

          _MediaSection(
            title: 'Profile photos',
            subtitle:
                'The first one is your main picture. '
                'Up to ${AppConfig.maxProfilePhotos}.',
            items: account.profilePhotos,
            limit: AppConfig.maxProfilePhotos,
            onAdd: _uploadProgress != null
                ? null
                : () => _addMedia(MediaType.profilePhoto, account),
            onDelete: _delete,
          ),
          const SizedBox(height: AppSpacing.xxl),

          _MediaSection(
            title: 'Gallery',
            subtitle:
                'Up to ${AppConfig.maxGalleryPhotos} photos, '
                '${(AppConfig.maxImageBytes / 1024 / 1024).round()}MB each.',
            items: account.galleryPhotos,
            limit: AppConfig.maxGalleryPhotos,
            onAdd: _uploadProgress != null
                ? null
                : () => _addMedia(MediaType.galleryPhoto, account),
            onDelete: _delete,
          ),
          const SizedBox(height: AppSpacing.xxl),

          _MediaSection(
            title: 'Videos',
            subtitle:
                'Up to ${AppConfig.maxVideos} clips, '
                '${(AppConfig.maxVideoBytes / 1024 / 1024).round()}MB and '
                '60 seconds each.',
            items: account.videos,
            limit: AppConfig.maxVideos,
            isVideo: true,
            onAdd: _uploadProgress != null
                ? null
                : () => _addMedia(MediaType.video, account),
            onDelete: _delete,
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.limit,
    required this.onDelete,
    this.onAdd,
    this.isVideo = false,
  });

  final String title;
  final String subtitle;
  final List<MediaItem> items;
  final int limit;
  final VoidCallback? onAdd;
  final Future<void> Function(MediaItem) onDelete;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              '${items.length}/$limit',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: items.length + (items.length < limit ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _AddTile(onTap: onAdd, isVideo: isVideo);
            }
            return _MediaTile(
              item: items[index],
              isVideo: isVideo,
              onDelete: () => onDelete(items[index]),
              onOpen: () => openMediaViewer(
                context,
                items: items,
                initialIndex: index,
                title: title,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.isVideo,
    required this.onDelete,
    required this.onOpen,
  });

  final MediaItem item;
  final bool isVideo;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          onTap: onOpen,
          child: isVideo
              ? Container(
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                )
              : ProfileImage(
                  url: item.url,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
        ),

        if (!item.isApproved)
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                'Awaiting review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.sansFamily,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        Positioned(
          top: 2,
          right: 2,
          child: Semantics(
            button: true,
            label: 'Remove this file',
            child: InkWell(
              onTap: onDelete,
              customBorder: const CircleBorder(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.isVideo});

  final VoidCallback? onTap;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isVideo ? 'Add a video' : 'Add a photo',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: onTap == null ? AppColors.border : AppColors.borderActive,
            ),
          ),
          child: Center(
            child: Icon(
              isVideo ? Icons.videocam_outlined : Icons.add_a_photo_outlined,
              size: 24,
              color: onTap == null ? AppColors.textMuted : AppColors.rose,
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Uploading… ${(value * 100).round()}%',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(value: value, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

class _UploadNotAvailable extends StatelessWidget {
  const _UploadNotAvailable();

  @override
  Widget build(BuildContext context) {
    return const EmptyView(
      icon: Icons.photo_camera_back_outlined,
      title: 'Uploads are for listed profiles',
      message:
          'On Pinorpinor, public profiles with photos and videos belong to '
          'women members. Your account can browse, match and message.',
    );
  }
}
