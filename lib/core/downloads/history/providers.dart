// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../download_manager/providers.dart';
import '../../download_manager/types.dart';
import '../background/types.dart';
import '../downloader/types.dart' show DownloaderMetadata;
import 'src/repo_io.dart' if (dart.library.js_interop) 'src/repo_web.dart';
import 'types.dart';

export 'src/repo_io.dart' if (dart.library.js_interop) 'src/repo_web.dart';

final downloadHistoryProvider =
    AsyncNotifierProvider<DownloadHistoryNotifier, DownloadHistoryState>(
      DownloadHistoryNotifier.new,
    );

final postDownloadStatusProvider =
    Provider.family<PostDownloadStatus, DownloadedPostKey>(
      (ref, key) => ref.watch(
        downloadHistoryProvider.select(
          (state) => state.value?.statusOf(key) ?? PostDownloadStatus.none,
        ),
      ),
    );

class DownloadHistoryNotifier extends AsyncNotifier<DownloadHistoryState> {
  @override
  Future<DownloadHistoryState> build() async {
    final repo = await ref.watch(downloadedPostRepoProvider.future);
    final keys = await repo.getAllKeys();

    return DownloadHistoryState(downloaded: keys, pending: const {});
  }

  Future<PostDownloadStatus> statusOf(DownloadedPostKey key) async =>
      (await future).statusOf(key);

  Future<void> markPending(DownloadedPostKey key) async {
    final current = await future;
    state = AsyncData(current.copyWith(pending: {...current.pending, key}));
  }

  Future<void> clearPending(DownloadedPostKey key) async {
    final current = await future;
    if (!current.pending.contains(key)) return;

    state = AsyncData(
      current.copyWith(pending: {...current.pending}..remove(key)),
    );
  }

  Future<void> markDownloaded(DownloadedPost post) async {
    final current = await future;
    final repo = await ref.read(downloadedPostRepoProvider.future);
    await repo.add(post);

    state = AsyncData(
      current.copyWith(
        downloaded: {...current.downloaded, post.key},
        pending: {...current.pending}..remove(post.key),
      ),
    );
  }

  Future<void> forget(DownloadedPostKey key) async {
    final current = await future;
    final repo = await ref.read(downloadedPostRepoProvider.future);
    await repo.remove(key);

    state = AsyncData(
      current.copyWith(
        downloaded: {...current.downloaded}..remove(key),
        pending: {...current.pending}..remove(key),
      ),
    );
  }
}

/// Progress of a post's active download: null when nothing runs, 0 while it
/// waits in the queue, and up to 1 as bytes arrive.
final postDownloadProgressProvider = Provider.autoDispose
    .family<double?, DownloadedPostKey>((ref, key) {
      final state = ref.watch(downloadTaskUpdatesProvider);

      for (final updates in state.tasks.values) {
        for (final update in updates.reversed) {
          final metadata = DownloaderMetadata.fromJsonString(
            update.task.metaData,
          );
          if (metadata.postId != key.postId ||
              metadata.siteUrl != key.siteUrl) {
            continue;
          }

          return switch (update) {
            TaskProgressUpdate(:final progress)
                when progress >= 0 && progress < 1 =>
              progress,
            TaskStatusUpdate(
              status: TaskStatus.enqueued ||
                  TaskStatus.running ||
                  TaskStatus.waitingToRetry,
            ) =>
              0,
            _ => null,
          };
        }
      }

      return null;
    });
