// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../ddos/handler/providers.dart';
import '../../../downloads/background/types.dart';
import '../../../http/client/providers.dart';
import '../../types.dart';
import '../data/file_downloader_task_client.dart';
import '../providers/download_task_updates_notifier.dart';
import '../providers/internal_providers.dart';

class RetryAllFailedButton extends ConsumerWidget {
  const RetryAllFailedButton({
    super.key,
    this.filter,
  });

  final String? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref
        .watch(downloadTaskUpdatesProvider)
        .failed(
          ref.watch(downloadGroupProvider),
        );
    final config = ref.watchConfig;

    return ref.watch(downloadFilterProvider(filter)) == DownloadFilter.failed &&
            failed.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: () => retryDownloadTasks(
                ref,
                failed.map((e) => e.task),
                auth: config.auth,
              ),
              child: Text(context.t.download.retry_all),
            ),
          )
        : const SizedBox.shrink();
  }
}

/// Starts [tasks] again with fresh request and protection headers.
void retryDownloadTasks(
  WidgetRef ref,
  Iterable<Task> tasks, {
  required BooruConfigAuth auth,
}) {
  for (final task in tasks) {
    final dt = castOrNull<DownloadTask>(task);
    if (dt == null) continue;

    ref.invalidate(bypassDdosHeadersProvider(dt.url));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        final headers = ref.read(httpHeadersProvider(auth));
        final bypassHeaders = await ref.read(
          bypassDdosHeadersProvider(dt.url).future,
        );
        await ref
            .read(downloadTaskClientProvider)
            .retry(
              dt,
              headers: headers,
              bypassHeaders: bypassHeaders,
            );
      },
    );
  }
}
