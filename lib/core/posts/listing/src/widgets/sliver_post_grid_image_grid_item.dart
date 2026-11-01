// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/gesture/types.dart';
import '../../../../downloads/history/providers.dart';
import '../../../../downloads/history/types.dart';
import '../../../../settings/providers.dart';
import '../../../post/tags.dart';
import '../../../post/types.dart';
import '../../../post/widgets.dart';
import '../types/image_list_type.dart';

class BlockOverlayItem {
  const BlockOverlayItem({
    required this.overlay,
    this.onTap,
  });

  final VoidCallback? onTap;
  final Widget overlay;
}

class SliverPostGridImageGridItem<T extends Post> extends ConsumerWidget {
  const SliverPostGridImageGridItem({
    required this.post,
    required this.index,
    required this.quickActionButton,
    required this.autoScrollOptions,
    required this.onTap,
    required this.image,
    required this.score,
    required this.multiSelectEnabled,
    super.key,
    this.blockOverlay,
    this.leadingIcons,
  });

  final T post;
  final int index;
  final Widget? quickActionButton;
  final AutoScrollOptions? autoScrollOptions;
  final VoidCallback? onTap;
  final Widget image;
  final int? score;
  final BlockOverlayItem? blockOverlay;
  final bool multiSelectEnabled;
  final List<Widget>? leadingIcons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = blockOverlay;
    final hideOverlay = multiSelectEnabled;

    final auth = ref.watchConfigAuth;
    final booruRepo = ref.watch(booruRepoProvider(auth));
    final gestures = ref.watchPostGestures?.preview;

    final imageBorderRadius = ref.watch(
      imageListingSettingsProvider.select(
        (value) => value.imageBorderRadius,
      ),
    );

    final showScoresInGrid = ref.watch(
      imageListingSettingsProvider.select(
        (value) => value.showScoresInGrid,
      ),
    );

    final scoreWidget = showScoresInGrid
        ? score.toOption().fold(
            () => null,
            (s) => s == 0 ? null : ImageScoreWidget(score: s),
          )
        : null;

    final imageListType = ref.watch(
      imageListingSettingsProvider.select((v) => v.imageListType),
    );

    return GestureDetector(
      onLongPress: gestures.canLongPress && booruRepo != null
          ? () => booruRepo.handlePostGesture(
              ref,
              gestures?.longPress,
              post,
            )
          : null,
      child: Stack(
        children: [
          ImageGridItem(
            leadingIcons: leadingIcons,
            trailingBadge: _DownloadedBadge(
              downloadKey: (siteUrl: auth.url, postId: post.id),
            ),
            borderRadius: BorderRadius.circular(imageBorderRadius),
            isGif: post.isGif,
            isAI: post.isAI,
            hideOverlay: hideOverlay,
            quickActionButton: quickActionButton,
            autoScrollOptions: autoScrollOptions,
            splashColor: multiSelectEnabled ? Colors.transparent : null,
            onTap: multiSelectEnabled
                ? () {
                    SelectionMode.of(context).toggleItem(index);
                  }
                : () {
                    if (gestures.canTap && booruRepo != null) {
                      booruRepo.handlePostGesture(
                        ref,
                        gestures?.tap,
                        post,
                      );
                    } else {
                      onTap?.call();
                    }
                  },
            image: image,
            isAnimated: post.isAnimated,
            isTranslated: post.isTranslated,
            hasComments: post.hasComment,
            hasParentOrChildren: post.hasParentOrChildren,
            hasSound: post.hasSound,
            duration: post.duration,
            scoreWidget: scoreWidget,
          ),
          if (overlay != null) ...[
            Positioned.fill(
              child: InkWell(
                highlightColor: Colors.transparent,
                splashFactory: FasterInkSplash.splashFactory,
                splashColor: Colors.black38,
                onTap: blockOverlay?.onTap,
              ),
            ),
            if (imageListType == ImageListType.masonry)
              Positioned.fill(
                child: Center(
                  child: overlay.overlay,
                ),
              )
            else
              Align(
                child: overlay.overlay,
              ),
          ],
        ],
      ),
    );
  }
}

class _DownloadedBadge extends ConsumerWidget {
  const _DownloadedBadge({required this.downloadKey});

  final DownloadedPostKey downloadKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(postDownloadProgressProvider(downloadKey))
        case final progress?) {
      final colors = Kurumi.semanticColorsOf(context);

      return Container(
        width: 24,
        height: 24,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.overlayDim,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: CircularProgressIndicator(
          value: progress > 0 ? progress : null,
          strokeWidth: 2,
          color: colors.onOverlayDim,
        ),
      );
    }

    return switch (ref.watch(postDownloadStatusProvider(downloadKey))) {
      PostDownloadStatus.downloaded => const ImageOverlayIcon(
        icon: Symbols.offline_pin,
      ),
      PostDownloadStatus.pending => const ImageOverlayIcon(
        icon: Symbols.downloading,
      ),
      PostDownloadStatus.none => const SizedBox.shrink(),
    };
  }
}
