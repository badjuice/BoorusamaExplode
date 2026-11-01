// Package imports:
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/download_manager/providers.dart';
import 'package:boorusama/core/download_manager/types.dart';

void main() {
  test('every update to an already tracked group reaches listeners', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final task = DownloadTask(taskId: 'task-1', url: 'https://file.test/1');
    final snapshots = <DownloadTaskUpdateState>[];
    container.listen(
      downloadTaskUpdatesProvider,
      (_, next) => snapshots.add(next),
    );
    final notifier = container.read(downloadTaskUpdatesProvider.notifier);

    notifier
      ..addOrUpdate(TaskStatusUpdate(task, TaskStatus.running))
      ..addOrUpdate(TaskProgressUpdate(task, 0.5))
      ..addOrUpdate(TaskStatusUpdate(task, TaskStatus.complete));

    expect(snapshots, hasLength(3));
    expect(
      snapshots.map((state) => state.tasks[task.group]!.single),
      [
        isA<TaskStatusUpdate>().having(
          (u) => u.status,
          'status',
          TaskStatus.running,
        ),
        isA<TaskProgressUpdate>().having((u) => u.progress, 'progress', 0.5),
        isA<TaskStatusUpdate>().having(
          (u) => u.status,
          'status',
          TaskStatus.complete,
        ),
      ],
    );
  });

  final lateArrivals = [
    (
      name: 'progress after completion keeps the task completed',
      updates: [TaskStatus.complete, 0.9],
      tab: 'completed',
    ),
    (
      name: 'enqueued after progress keeps the task in progress',
      updates: [0.3, TaskStatus.enqueued],
      tab: 'inProgress',
    ),
    (
      name: 'a retry after failure moves the task back to pending',
      updates: [TaskStatus.failed, TaskStatus.enqueued],
      tab: 'pending',
    ),
    (
      name: 'a running task is listed in progress before any progress',
      updates: [TaskStatus.enqueued, TaskStatus.running],
      tab: 'inProgress',
    ),
  ];

  for (final c in lateArrivals) {
    test(c.name, () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final task = DownloadTask(taskId: 'task-1', url: 'https://file.test/1');
      final notifier = container.read(downloadTaskUpdatesProvider.notifier);

      for (final u in c.updates) {
        notifier.addOrUpdate(switch (u) {
          final TaskStatus s => TaskStatusUpdate(task, s),
          final double p => TaskProgressUpdate(task, p),
          _ => throw ArgumentError(u),
        });
      }

      final state = container.read(downloadTaskUpdatesProvider);
      final tabs = {
        'pending': state.pending(task.group),
        'inProgress': state.inProgress(task.group),
        'completed': state.completed(task.group),
      };
      expect(
        tabs.entries.where((e) => e.value.isNotEmpty).map((e) => e.key),
        [c.tab],
      );
    });
  }
}
