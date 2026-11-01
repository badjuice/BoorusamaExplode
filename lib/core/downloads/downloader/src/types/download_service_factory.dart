// Package imports:
import 'package:background_downloader/background_downloader.dart';
import 'package:cache_manager/cache_manager.dart';

// Project imports:
import '../../../../../foundation/filesystem.dart';
import '../../../../../foundation/loggers.dart';
import '../../../sidecar/src/data/sidecar_store.dart';
import 'download.dart';

final class DownloadServiceDependencies {
  const DownloadServiceDependencies({
    required this.fileSystem,
    required this.logger,
    required this.sidecarStore,
    required this.videoCacheManager,
    required this.androidSdkInt,
    this.publishTaskUpdate,
  });

  final AppFileSystem? fileSystem;
  final Logger? logger;
  final Future<SidecarStore>? sidecarStore;
  final VideoCacheManager? videoCacheManager;
  final int? androidSdkInt;

  /// Reports downloads finished without a native task, such as copies from
  /// the video cache, so the download manager can list them.
  final void Function(TaskUpdate update)? publishTaskUpdate;
}

abstract interface class DownloadServiceFactory {
  DownloadService create(DownloadServiceDependencies dependencies);

  Future<void> dispose(DownloadService service);
}
