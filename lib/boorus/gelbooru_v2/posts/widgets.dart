// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:foundation/widgets.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/posts/details/routes.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details/widgets.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/router.dart';
import '../../../core/search/search/routes.dart';
import '../gelbooru_v2_provider.dart';
import 'providers.dart';
import 'types.dart';

class GelbooruV2PostDetailsPage extends ConsumerWidget {
  const GelbooruV2PostDetailsPage({
    required this.payload,
    super.key,
  });

  final DetailsRouteContext payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configSearch = ref.watchConfigSearch;

    final postId = payload.posts.getOrNull(payload.initialIndex)?.id;

    if (postId == null) {
      return InvalidPage(message: 'Invalid post: $postId');
    }

    final gelbooruV2 = ref.watch(gelbooruV2Provider);

    final thumbnailOnly =
        gelbooruV2
            .getCapabilitiesForSite(configSearch.auth.url)
            ?.posts
            ?.thumbnailOnly ??
        false;

    final posts = payload.posts.map((e) => e as GelbooruV2Post).toList();

    return PostDetailsScope<GelbooruV2Post>(
      initialIndex: payload.initialIndex,
      initialThumbnailUrl: payload.initialThumbnailUrl,
      posts: posts,
      scrollController: payload.scrollController,
      dislclaimer: payload.dislclaimer,
      // Listing entries of thumbnail-only sites lack the real file url and
      // most metadata, so each post page is fetched as it comes into view.
      postResolver: thumbnailOnly
          ? (post) async {
              final provider = gelbooruV2PostProvider(
                (NumericPostId(post.id), configSearch),
              );

              return switch (await ref.read(provider.future)) {
                final GelbooruV2Post p => p,
                _ => () {
                  ref.invalidate(provider);
                  return null;
                }(),
              };
            }
          : null,
      child: const DefaultPostDetailsPage<GelbooruV2Post>(),
    );
  }
}

class GelbooruV2UploaderFileDetailTile extends ConsumerWidget {
  const GelbooruV2UploaderFileDetailTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<GelbooruV2Post>(context);
    final uploaderName = post.uploaderName;

    return switch (uploaderName) {
      null => const SizedBox.shrink(),
      final name => UploaderFileDetailTile(
        uploaderName: name,
        onSearch: switch (ref.watch(gelbooruV2UploaderQueryProvider(post))) {
          final query? => () => goToSearchPage(
            ref,
            tag: query.resolveTag(),
          ),
          _ => null,
        },
      ),
    };
  }
}

class GelbooruV2RelatedPostsSection extends ConsumerWidget {
  const GelbooruV2RelatedPostsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<GelbooruV2Post>(context);

    return post.hasParent
        ? ref
              .watch(
                gelbooruV2ChildPostsProvider(
                  (ref.watchConfigFilter, ref.watchConfigSearch, post),
                ),
              )
              .maybeWhen(
                data: (data) => SliverRelatedPostsSection(
                  title: 'Child posts',
                  posts: data,
                  imageUrl: (post) => post.sampleImageUrl,
                  onViewAll: () => goToSearchPage(
                    ref,
                    tag: post.relationshipQuery,
                  ),
                  onTap: (index) => goToPostDetailsPageFromPosts(
                    ref: ref,
                    posts: data,
                    initialIndex: index,
                    initialThumbnailUrl: data[index].sampleImageUrl,
                  ),
                ),
                orElse: () => const SliverSizedBox.shrink(),
              )
        : const SliverSizedBox.shrink();
  }
}

class GelbooruV2UploaderPostsSection extends ConsumerWidget {
  const GelbooruV2UploaderPostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<GelbooruV2Post>(context);

    return UploaderPostsSection<GelbooruV2Post>(
      query: ref.watch(
        gelbooruV2UploaderQueryProvider(post),
      ),
    );
  }
}

final kGelbooruV2PostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<GelbooruV2Post>(),
  },
  full: {
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<GelbooruV2Post>(),
    DetailsPart.source: (context) =>
        const DefaultInheritedSourceSection<GelbooruV2Post>(),
    DetailsPart.tags: (context) =>
        const DefaultInheritedTagsTile<GelbooruV2Post>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<GelbooruV2Post>(
          uploader: GelbooruV2UploaderFileDetailTile(),
        ),
    DetailsPart.artistPosts: (context) =>
        const DefaultInheritedArtistPostsSection<GelbooruV2Post>(),
    DetailsPart.uploaderPosts: (context) =>
        const GelbooruV2UploaderPostsSection(),
    DetailsPart.relatedPosts: (context) =>
        const GelbooruV2RelatedPostsSection(),
    DetailsPart.characterList: (context) =>
        const DefaultInheritedCharacterPostsSection<GelbooruV2Post>(),
  },
);
