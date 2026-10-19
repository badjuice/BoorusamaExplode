// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../post/types.dart';
import '../types/post_details.dart';

/// Shown in place of a post whose full data is still being fetched: the
/// thumbnail with a small spinner, or a retry button if fetching failed.
class PostDetailsResolvingItem extends StatelessWidget {
  const PostDetailsResolvingItem({
    required this.post,
    required this.status,
    required this.authConfig,
    required this.onRetry,
    super.key,
  });

  final Post post;
  final PostResolveStatus status;
  final BooruConfigAuth authConfig;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (post.thumbnailImageUrl.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: status == PostResolveStatus.failed ? 0.35 : 1,
              child: BooruImage(
                imageUrl: post.thumbnailImageUrl,
                config: authConfig,
                fit: BoxFit.contain,
                aspectRatio: post.aspectRatio,
              ),
            ),
          ),
        switch (status) {
          PostResolveStatus.loading => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
          PostResolveStatus.failed => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.cloud_off,
                size: 32,
                color: colorScheme.onSurface,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh),
                label: Text(context.t.generic.action.retry),
              ),
            ],
          ),
        },
      ],
    );
  }
}
