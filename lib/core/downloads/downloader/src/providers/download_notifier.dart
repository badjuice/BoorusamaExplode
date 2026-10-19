// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

// Project imports:
import '../../../../../foundation/loggers.dart';
import '../../../../../foundation/permissions.dart';
import '../../../../../foundation/platform.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/network/providers.dart';
import '../../../../ddos/handler/providers.dart';
import '../../../../download_activity/activity.dart';
import '../../../../http/client/types.dart';
import '../../../../posts/post/providers.dart';
import '../../../../posts/post/types.dart';
import '../../../../router.dart';
import '../../../../settings/types.dart';
import '../../../filename/types.dart';
import '../../../history/providers.dart';
import '../../../history/types.dart';
import '../../../organization/providers.dart';
import '../../../organization/types.dart';
import '../../../sidecar/types.dart';
import '../../../urls/types.dart';
import '../types/download.dart';
import '../types/download_network_policy.dart';
import '../types/metadata.dart';
import '../types/observer.dart';
import 'download_network_policy_provider.dart';

final downloadNotifierProvider =
    NotifierProvider.family<DownloadNotifier, void, DownloadNotifierParams>(
      DownloadNotifier.new,
    );

typedef DownloadNotifierParams = ({
  BooruConfigAuth auth,
  BooruConfigDownload download,
  String? profileIconUrl,
  DownloadFileUrlExtractor downloadFileUrlExtractor,
  DownloadFilenameGenerator? filenameBuilder,
  DownloadObserver? observer,
  MultipleFileDownloadCheck canDownloadMultipleFiles,
  Map<String, String> headers,
  Settings settings,
  DownloadService downloader,
  Logger logger,
});

typedef MultipleFileDownloadCheck = bool Function();

class DownloadNotifier extends FamilyNotifier<void, DownloadNotifierParams> {
  @override
  void build(DownloadNotifierParams arg) {
    return;
  }

  Future<PermissionStatus?> _getPermissionStatus() async {
    final perm = await ref.read(deviceStoragePermissionProvider.future);
    return ref.read(appPlatformProvider).isMobile
        ? perm.storagePermission
        : null;
  }

  Future<DownloadTaskInfo?> download(
    Post post, {
    String? overrideUrl,
    String? quality,
  }) async {
    // Picking a quality from the menu is an explicit request to save again.
    final isExplicit = overrideUrl != null || quality != null;
    if (!isExplicit && await _isAlreadyDownloaded(post)) {
      _showToast(
        (context) => context.t.download.notification.already_downloaded,
      );
      return null;
    }

    final perm = await _getPermissionStatus();
    final observer = arg.observer;

    final info = await _download(
      ref,
      post,
      params: arg,
      permission: perm,
      overrideUrl: overrideUrl,
      quality: quality,
      onStarted: () {
        observer?.onSingleDownloadStart();
      },
    );

    return info;
  }

  Future<void> bulkDownload(
    List<Post> posts, {
    String? group,
    String? downloadPath,
  }) async {
    // ensure that the booru supports bulk download
    if (!arg.canDownloadMultipleFiles()) {
      final context = ref
          .read(appNavigationProvider)
          .navigatorKey
          .currentState
          ?.context;

      showBulkDownloadUnsupportErrorToast(context);
      return;
    }

    final newPosts = [
      for (final post in posts)
        if (!await _isAlreadyDownloaded(post)) post,
    ];
    final skipped = posts.length - newPosts.length;

    if (skipped > 0) {
      _showToast(
        (context) => newPosts.isEmpty
            ? context.t.download.notification.already_downloaded
            : context.t.download.notification.skipped_already_downloaded
                  .replaceAll('{count}', skipped.toString()),
      );
    }
    if (newPosts.isEmpty) return;

    final perm = await _getPermissionStatus();
    final networkConstraint = await resolveDownloadNetworkConstraint(
      ref,
      arg.settings.downloadNetworkPolicy,
    );
    if (networkConstraint == null) return;

    arg.observer?.onBulkDownloadStart(
      total: newPosts.length,
    );

    for (var i = 0; i < newPosts.length; i++) {
      final post = newPosts[i];
      await _download(
        ref,
        post,
        params: arg,
        permission: perm,
        group: group,
        downloadPath: downloadPath,
        bulkMetadata: {
          'total': newPosts.length.toString(),
          'index': i.toString(),
        },
        networkConstraint: networkConstraint,
      );
    }
  }

  Future<bool> _isAlreadyDownloaded(Post post) async {
    final status = await ref.read(downloadHistoryProvider.notifier).statusOf((
      siteUrl: arg.auth.url,
      postId: post.id,
    ));

    return status != PostDownloadStatus.none;
  }

  void _showToast(String Function(BuildContext context) message) {
    final context = ref
        .read(appNavigationProvider)
        .navigatorKey
        .currentState
        ?.context;
    if (context == null || !context.mounted) return;

    showDownloadStartToast(context, message: message(context));
  }
}

void _recordOutcome(
  Ref ref,
  DownloadResult result, {
  required String siteUrl,
  required Post post,
}) {
  final history = ref.read(downloadHistoryProvider.notifier);
  final key = (siteUrl: siteUrl, postId: post.id);

  unawaited(
    switch (result) {
      DownloadEnqueued() => history.markPending(key),
      DownloadCompleted(:final info) ||
      DownloadSkipped(:final info) => history.markDownloaded(
        DownloadedPost(
          siteUrl: siteUrl,
          postId: post.id,
          downloadedAt: DateTime.now(),
          filePath: info.path,
          thumbnailUrl: post.thumbnailImageUrl,
          isVideo: post.isVideo,
        ),
      ),
      DownloadFailure() => history.clearPending(key),
    },
  );
}

Future<DownloadTaskInfo?> _download(
  Ref ref,
  Post downloadable, {
  required DownloadNotifierParams params,
  PermissionStatus? permission,
  String? group,
  String? downloadPath,
  Map<String, String>? bulkMetadata,
  void Function()? onStarted,
  //FIXME: bad solution, need better design
  String? overrideUrl,
  String? quality,
  DownloadNetworkConstraint? networkConstraint,
}) async {
  final downloadConfig = params.download;
  final service = params.downloader;
  final fileNameBuilder = params.filenameBuilder;
  final logger = params.logger;

  final headers = params.headers;

  final deviceStoragePermissionNotifier = ref.read(
    deviceStoragePermissionProvider.notifier,
  );

  final effectiveQuality = quality ?? params.settings.downloadQuality.name;
  final urlData = overrideUrl != null
      ? DownloadUrlData.urlOnly(overrideUrl)
      : await params.downloadFileUrlExtractor.getDownloadFileUrl(
          post: downloadable,
          quality: effectiveQuality,
        );

  if (fileNameBuilder == null) {
    logger.error('Single Download', 'No file name builder found, aborting...');
    // if (ref.context.mounted) {
    //   Kurumi.showErrorToast(ref.context, 'Download aborted, cannot create file name');
    // }
    return null;
  }

  if (urlData == null || urlData.url.isEmpty) {
    logger.error('Single Download', 'No download url found, aborting...');
    // if (ref.context.mounted) {
    //   Kurumi.showErrorToast(ref.context, 'Download aborted, no download url found');
    // }
    return null;
  }

  final resolvedNetworkConstraint =
      networkConstraint ??
      await resolveDownloadNetworkConstraint(
        ref,
        params.settings.downloadNetworkPolicy,
      );
  if (resolvedNetworkConstraint == null) return null;

  Future<DownloadTaskInfo?> download() async {
    final fileNameFuture = bulkMetadata != null
        ? fileNameBuilder.generateForBulkDownload(
            params.settings,
            downloadConfig,
            downloadable,
            metadata: bulkMetadata,
            downloadUrl: urlData.url,
          )
        : fileNameBuilder.generate(
            params.settings,
            downloadConfig,
            downloadable,
            downloadUrl: urlData.url,
          );

    final fileName = await fileNameFuture;

    final network = ref.read(networkSettingsProvider(params.auth));
    final request = network.resolveMedia(
      urlData.url,
      headers: {
        ...headers,
        if (urlData.cookie != null)
          AppHttpHeaders.cookieHeader: urlData.cookie!,
      },
    );
    final bypassHeaders = await ref.read(
      bypassDdosHeadersProvider(request.url).future,
    );

    final result = await service.download(
      DownloadOptions.fromSettings(
        params.settings,
        config: downloadConfig,
        sidecar: params.settings.downloadSidecarFormat == SidecarFormat.off
            ? null
            : SidecarSnapshot.fromPost(
                downloadable,
                format: params.settings.downloadSidecarFormat,
                quality: effectiveQuality,
                site: params.auth.url,
                postUrl: ref
                    .read(postLinkGeneratorProvider(params.auth))
                    .getLink(downloadable),
              ),
        metadata: DownloaderMetadata(
          mediaHostOverridden: request.overridden,
          thumbnailUrl: downloadable.thumbnailImageUrl,
          fileSize: downloadable.fileSize,
          siteUrl: params.auth.url,
          profileIconUrl: params.profileIconUrl,
          group: group,
          isVideo: downloadable.isVideo,
          postId: downloadable.id,
        ),
        url: request.url,
        filename: fileName,
        headers: {
          ...request.headers,
          ...bypassHeaders,
          if (!request.overridden && urlData.cookie != null)
            AppHttpHeaders.cookieHeader: urlData.cookie!,
        },
        customPath: downloadPath,
        folderName: downloadSubfolder(
          bySite: params.settings.downloadFolderBySite,
          bySearch: params.settings.downloadFolderBySearch,
          byMediaType: params.settings.downloadFolderByMediaType,
          siteUrl: params.auth.url,
          searchQuery: ref.read(activeSearchQueryProvider),
          mediaKind: switch (downloadable) {
            Post(isVideo: true) => DownloadMediaKind.video,
            Post(isGif: true) => DownloadMediaKind.gif,
            _ => DownloadMediaKind.image,
          },
        ),
        networkConstraint: resolvedNetworkConstraint,
      ),
    );

    _recordOutcome(
      ref,
      result,
      siteUrl: params.auth.url,
      post: downloadable,
    );

    ref
        .read(immediateDownloadActivitiesProvider.notifier)
        .recordImmediateOutcome(
          result,
          label: fileName,
          thumbnailUrl: downloadable.thumbnailImageUrl,
        );

    return switch (result) {
      DownloadEnqueued(:final info) => () {
        onStarted?.call();

        return info;
      }(),
      DownloadCompleted(:final info) => () {
        onStarted?.call();
        return info;
      }(),
      DownloadSkipped(:final info) => () {
        onStarted?.call();
        return info;
      }(),
      final DownloadFailure e => () {
        final msg = e.error.getErrorMessage();

        logger.error(
          'Single Download',
          'Download failed: ${e.error.runtimeType}',
          sensitiveMessage: msg,
        );
      }(),
    };
  }

  // Platform doesn't require permissions, just download it right away
  if (permission == null) {
    return download();
  }

  if (permission == PermissionStatus.granted) {
    return download();
  } else {
    logger.info('Single Download', 'Permission not granted, requesting...');
    DownloadTaskInfo? info;

    await deviceStoragePermissionNotifier.requestPermission(
      onDone: (isGranted) async {
        if (isGranted) {
          info = await download();
        } else {
          logger.info(
            'Single Download',
            'Storage permission request denied, aborting...',
          );
        }
      },
    );

    return info;
  }
}

void showDownloadErrorToast(
  BuildContext? context,
  String message,
) {
  if (context == null) return;
  if (!context.mounted) return;

  Kurumi.showErrorToast(
    context,
    duration: const Duration(seconds: 5),
    message,
  );
}

void showDownloadStartToast(BuildContext context, {String? message}) {
  final colorScheme = Theme.of(context).colorScheme;

  showToast(
    message ?? context.t.download.notification.started,
    position: ToastPosition.bottom,
    margin: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 60,
    ),
    textPadding: const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 4,
    ),
    duration: const Duration(seconds: 2),
    backgroundColor: colorScheme.surfaceContainerHigh,
    textStyle: TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );
}

void showBulkDownloadUnsupportErrorToast(BuildContext? context) {
  if (context == null) return;

  Kurumi.showErrorToast(
    context,
    duration: const Duration(seconds: 3),
    'This booru does not support downloading multiple files',
  );
}
