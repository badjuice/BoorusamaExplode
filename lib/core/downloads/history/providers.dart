// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
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
      current.copyWith(downloaded: {...current.downloaded}..remove(key)),
    );
  }
}
