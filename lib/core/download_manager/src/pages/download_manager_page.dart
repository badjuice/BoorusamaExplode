// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:share_plus/share_plus.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../ddos/handler/providers.dart';
import '../../../downloads/background/types.dart';
import '../../../http/client/providers.dart';
import '../../../downloads/history/widgets.dart';
import '../../../settings/providers.dart';
import '../../../settings/routes.dart';
import '../../../widgets/default_selection_bar.dart';
import '../../../widgets/widgets.dart';
import '../../types.dart';
import '../l10n.dart';
import '../data/file_downloader_task_client.dart';
import '../providers/download_task_updates_notifier.dart';
import '../providers/internal_providers.dart';
import '../widgets/download_selectable_item.dart';
import '../widgets/retry_all_failed_button.dart';
import '../widgets/simple_download_tile.dart';

class DownloadManagerGatewayPage extends ConsumerWidget {
  const DownloadManagerGatewayPage({
    super.key,
    this.filter,
    this.group,
  });

  final String? filter;
  final String? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        downloadGroupProvider.overrideWithValue(
          group ?? FileDownloader.defaultGroup,
        ),
      ],
      child: DownloadManagerPage(
        filter: filter,
      ),
    );
  }
}

class DownloadManagerPage extends ConsumerStatefulWidget {
  const DownloadManagerPage({
    super.key,
    this.filter,
  });

  final String? filter;

  @override
  ConsumerState<DownloadManagerPage> createState() =>
      _DownloadManagerPageState();
}

class _DownloadManagerPageState extends ConsumerState<DownloadManagerPage>
    with SingleTickerProviderStateMixin {
  final _selectionModeController = SelectionModeController();
  final _scrollControllers = {
    for (final filter in kFilterOptions) filter: AutoScrollController(),
  };
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    final initialIndex = kFilterOptions.indexOf(convertFilter(widget.filter));

    _tabController = TabController(
      length: kFilterOptions.length,
      initialIndex: initialIndex == -1 ? 0 : initialIndex,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final filter = kFilterOptions[_tabController.index];
    final notifier = ref.read(downloadFilterProvider(widget.filter).notifier);

    if (notifier.state == filter) return;

    _selectionModeController.disable();
    notifier.state = filter;
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _selectionModeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(downloadFilteredProvider(widget.filter));
    final currentFilter = ref.watch(downloadFilterProvider(widget.filter));
    final config = ref.watchConfig;
    final group = ref.watch(downloadGroupProvider);
    final isDefaultGroup = group == FileDownloader.defaultGroup;

    return SelectionMode(
      controller: _selectionModeController,
      scrollController: _scrollControllers[currentFilter],
      child: Scaffold(
        appBar: DefaultSelectionAppBar(
          itemsCount: tasks.length,
          appBar: AppBar(
            title: Text(
              context.t.download.downloads,
            ),
            actions: [
              if (isDefaultGroup &&
                  ref.watch(
                    settingsProvider.select((s) => s.downloadGalleryEnabled),
                  ))
                IconButton(
                  icon: const Icon(Symbols.photo_library),
                  tooltip: context.t.download.gallery.title,
                  onPressed: () => openDownloadsGallery(context),
                ),
              if (isDefaultGroup)
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    openDownloadSettingsPage(ref);
                  },
                ),
              KurumiPopupMenuButton(
                items: [
                  KurumiPopupMenuItem(
                    title: Text(context.t.generic.action.select),
                    onTap: () {
                      _selectionModeController.enable();
                    },
                  ),
                  KurumiPopupMenuItem(
                    title: Text(context.t.generic.action.clear),
                    onTap: () {
                      // clear default group only
                      var cleared = true;
                      ref
                          .read(downloadTaskUpdatesProvider.notifier)
                          .clear(
                            FileDownloader.defaultGroup,
                            onFailed: () {
                              cleared = false;
                              Kurumi.showSimpleSnackBar(
                                context: context,
                                content: Text(
                                  context.t.download.nothing_to_clear,
                                ),
                                duration: const Duration(seconds: 1),
                              );
                            },
                          );
                      if (cleared) {
                        unawaited(
                          FileDownloader().database.deleteAllRecords(
                            group: FileDownloader.defaultGroup,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectionConsumer(
                    builder: (_, controller, _) => IgnorePointer(
                      ignoring: controller.isActive,
                      child: _DownloadTabBar(controller: _tabController),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SelectionConsumer(
                      builder: (_, controller, _) => TabBarView(
                        controller: _tabController,
                        physics: controller.isActive
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        children: [
                          for (final filter in kFilterOptions)
                            _buildTab(filter, config),
                        ],
                      ),
                    ),
                  ),
                  RetryAllFailedButton(filter: widget.filter),
                ],
              ),
              SelectionConsumer(
                builder: (context, controller, _) {
                  final selectedItems = controller.selectedFrom(tasks).toList();

                  if (!controller.isActive) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MultiSelectionActionBar(
                      children: [
                        MultiSelectButton(
                          onPressed: selectedItems.isNotEmpty
                              ? () async {
                                  final futures = selectedItems
                                      .map(
                                        (task) => ref
                                            .read(downloadTaskClientProvider)
                                            .filePath(task.task),
                                      )
                                      .toList();
                                  final paths = await Future.wait(futures);

                                  await SharePlus.instance.share(
                                    ShareParams(
                                      files: paths
                                          .map((path) => XFile(path))
                                          .toList(),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Symbols.share),
                          name: context.t.post.action.share,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(DownloadFilter filter, BooruConfig config) {
    final tasks = ref.watch(downloadTasksByFilterProvider(filter));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: tasks.isNotEmpty
          ? SelectionCanvas(
              child: _buildList(tasks, config, _scrollControllers[filter]),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(filter.emptyLocalize(context)),
              ),
            ),
    );
  }

  Widget _buildList(
    List<TaskUpdate> tasks,
    BooruConfig config,
    ScrollController? scrollController,
  ) {
    return ListView.builder(
      controller: scrollController,
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return DownloadSelectableItem(
          index: index,
          item: SimpleDownloadTile(
            task: task,
            onTap: () {
              if (_selectionModeController.isActive) {
                _selectionModeController.toggleItem(index);
              }
            },
            onResume: () {
              final dt = castOrNull<DownloadTask>(task.task);

              if (dt == null) return;

              ref.read(downloadTaskClientProvider).resume(dt);
            },
            onPause: () {
              final dt = castOrNull<DownloadTask>(task.task);

              if (dt == null) return;

              ref.read(downloadTaskClientProvider).pause(dt);
            },
            onResumeFailed: () {
              final dt = castOrNull<DownloadTask>(task.task);

              if (dt == null) return;

              ref.read(downloadTaskClientProvider).resume(dt);
            },
            onRestart: () {
              ref.invalidate(bypassDdosHeadersProvider(task.task.url));
              WidgetsBinding.instance.addPostFrameCallback(
                (_) async {
                  final headers = ref.read(httpHeadersProvider(config.auth));
                  final bypassHeaders = await ref.read(
                    bypassDdosHeadersProvider(task.task.url).future,
                  );
                  await ref
                      .read(downloadTaskClientProvider)
                      .retry(
                        task.task,
                        headers: headers,
                        bypassHeaders: bypassHeaders,
                      );
                },
              );
            },
            onCancel: () {
              ref.read(downloadTaskClientProvider).cancel(task.task.taskId);
            },
          ),
        );
      },
    );
  }
}

class _DownloadTabBar extends ConsumerWidget {
  const _DownloadTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        for (final filter in kFilterOptions)
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(filter.localize(context)),
                const SizedBox(width: 6),
                _CountPill(
                  count: ref.watch(
                    downloadTasksByFilterProvider(filter).select(
                      (tasks) => tasks.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Always rendered, with a fixed minimum width, so tab labels don't move when
// a count changes.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final active = count > 0;

    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: active
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: active
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
