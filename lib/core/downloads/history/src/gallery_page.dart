// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../images/booru_image.dart';
import '../../../videos/engines/types.dart';
import '../../../videos/player/providers.dart';
import '../../../videos/player/widgets.dart';
import '../providers.dart';
import '../types.dart';

final downloadedPostsProvider =
    FutureProvider.autoDispose<List<DownloadedPost>>(
      (ref) async {
        // Refresh whenever something is downloaded or forgotten.
        ref.watch(downloadHistoryProvider);
        final repo = await ref.watch(downloadedPostRepoProvider.future);
        return repo.getAll();
      },
    );

void openDownloadsGallery(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const DownloadsGalleryPage()),
  );
}

class DownloadsGalleryPage extends ConsumerWidget {
  const DownloadsGalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(downloadedPostsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.t.download.gallery.title)),
      body: switch (posts) {
        AsyncData(value: final items) when items.isEmpty => Center(
          child: Text(context.t.download.gallery.empty),
        ),
        AsyncData(value: final items) => GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _GalleryTile(
            post: items[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    _GalleryViewer(posts: items, initialIndex: index),
              ),
            ),
          ),
        ),
        AsyncError(:final error) => Center(child: Text(error.toString())),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

bool _fileExists(String? path) => path != null && File(path).existsSync();

class _GalleryTile extends ConsumerWidget {
  const _GalleryTile({required this.post, required this.onTap});

  final DownloadedPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = post.filePath;
    final exists = _fileExists(path);
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    final image = switch ((exists, post.isVideo, post.thumbnailUrl)) {
      (true, false, _) => Image.file(
        File(path!),
        fit: BoxFit.cover,
        cacheWidth: 320,
        errorBuilder: (_, _, _) => const _MissingFile(),
      ),
      (_, _, final thumb?) when thumb.isNotEmpty => BooruImage(
        imageUrl: thumb,
        config: ref.watchConfigAuth,
        forceCover: true,
      ),
      _ => const _MissingFile(),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colorScheme.surfaceContainerHigh, child: image),
          if (post.isVideo)
            const Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Symbols.play_circle, color: Colors.white),
              ),
            ),
          if (!exists)
            ColoredBox(
              color: Colors.black45,
              child: Icon(Symbols.broken_image, color: colorScheme.error),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: exists
                  ? () => SharePlus.instance.share(
                      ShareParams(files: [XFile(path!)]),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingFile extends StatelessWidget {
  const _MissingFile();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Symbols.image_not_supported));
}

class _GalleryViewer extends ConsumerStatefulWidget {
  const _GalleryViewer({required this.posts, required this.initialIndex});

  final List<DownloadedPost> posts;
  final int initialIndex;

  @override
  ConsumerState<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends ConsumerState<_GalleryViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late var _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.posts[_page];
    final currentPath = current.filePath;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text('#${current.postId}'),
        actions: [
          if (_fileExists(currentPath))
            IconButton(
              icon: const Icon(Symbols.share),
              onPressed: () => SharePlus.instance.share(
                ShareParams(files: [XFile(currentPath!)]),
              ),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.posts.length,
        onPageChanged: (page) => setState(() => _page = page),
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          final path = post.filePath;

          if (!_fileExists(path)) {
            return _MissingFileActions(post: post);
          }

          return post.isVideo
              ? BooruVideo(
                  key: ValueKey(path),
                  url: Uri.file(path!).toString(),
                  aspectRatio: null,
                  sound: ref.watch(globalSoundStateProvider),
                  videoPlayerEngine: VideoPlayerEngine.videoPlayerPlugin,
                  shouldInitialize: index == _page,
                )
              : InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: Image.file(File(path!))),
                );
        },
      ),
    );
  }
}

class _MissingFileActions extends ConsumerWidget {
  const _MissingFileActions({required this.post});

  final DownloadedPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.broken_image, size: 40, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            context.t.download.gallery.file_missing,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () {
              ref.read(downloadHistoryProvider.notifier).forget(post.key);
              Navigator.of(context).pop();
            },
            child: Text(context.t.download.gallery.allow_redownload),
          ),
        ],
      ),
    );
  }
}
