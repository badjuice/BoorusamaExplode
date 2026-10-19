// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/downloads/history/providers.dart';
import 'package:boorusama/core/downloads/history/types.dart';

import '../riverpod_test_utils.dart';

const _key = (siteUrl: 'https://realbooru.com/', postId: 42);

DownloadedPost _post() => DownloadedPost(
  siteUrl: _key.siteUrl,
  postId: _key.postId,
  downloadedAt: DateTime(2026),
);

ProviderContainer _container([DownloadedPostRepository? repo]) {
  final repository = repo ?? InMemoryDownloadedPostRepository();
  return createContainer(
    overrides: [
      downloadedPostRepoProvider.overrideWith((ref) async => repository),
    ],
  );
}

void main() {
  test('a post moves from pending to downloaded when it completes', () async {
    final container = _container();
    final notifier = container.read(downloadHistoryProvider.notifier);

    expect(await notifier.statusOf(_key), PostDownloadStatus.none);

    await notifier.markPending(_key);
    expect(await notifier.statusOf(_key), PostDownloadStatus.pending);

    await notifier.markDownloaded(_post());
    expect(await notifier.statusOf(_key), PostDownloadStatus.downloaded);
  });

  test('a failed download clears the pending mark', () async {
    final container = _container();
    final notifier = container.read(downloadHistoryProvider.notifier);

    await notifier.markPending(_key);
    await notifier.clearPending(_key);

    expect(await notifier.statusOf(_key), PostDownloadStatus.none);
  });

  test('downloaded posts survive a reload from the repository', () async {
    final repo = InMemoryDownloadedPostRepository();
    final container = _container(repo);

    await container
        .read(downloadHistoryProvider.notifier)
        .markDownloaded(
          _post(),
        );
    container.invalidate(downloadHistoryProvider);

    expect(
      await container.read(downloadHistoryProvider.notifier).statusOf(_key),
      PostDownloadStatus.downloaded,
    );
  });

  test('forgetting a post allows it to be downloaded again', () async {
    final container = _container();
    final notifier = container.read(downloadHistoryProvider.notifier);

    await notifier.markDownloaded(_post());
    await notifier.forget(_key);

    expect(await notifier.statusOf(_key), PostDownloadStatus.none);
  });
}
