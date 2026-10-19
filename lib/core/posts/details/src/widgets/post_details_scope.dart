// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../../../foundation/display.dart';
import '../../../../settings/providers.dart';
import '../../../details_pageview/widgets.dart';
import '../../../post/types.dart';
import '../types/inherited_post.dart';
import '../types/post_details.dart';
import 'post_details_controller.dart';
import 'post_details_page_view_scope.dart';

class PostDetailsScope<T extends Post> extends ConsumerStatefulWidget {
  const PostDetailsScope({
    required this.initialIndex,
    required this.initialThumbnailUrl,
    required this.posts,
    required this.dislclaimer,
    required this.child,
    required this.scrollController,
    super.key,
    this.postResolver,
  });

  final int initialIndex;
  final String? initialThumbnailUrl;
  final List<T> posts;
  final String? dislclaimer;
  final AutoScrollController? scrollController;
  final Widget child;

  /// Fetches the full post for a partial listing entry. When set, each post
  /// is resolved as it comes into view and shown as a placeholder until then.
  final Future<T?> Function(T post)? postResolver;

  @override
  ConsumerState<PostDetailsScope<T>> createState() =>
      _PostDetailsLayoutSwitcherState<T>();
}

class _PostDetailsLayoutSwitcherState<T extends Post>
    extends ConsumerState<PostDetailsScope<T>> {
  late final PostDetailsController<T> _controller;
  late final PostDetailsPageViewController _pageViewController;
  late final List<T> _posts = List.of(widget.posts);
  final _resolved = <int>{};
  final _failed = <int>{};
  final _inflight = <int>{};

  @override
  void initState() {
    super.initState();

    final initialPage = widget.initialIndex;
    final settings = ref.read(settingsProvider);
    final viewerSettings = ref.read(imageViewerSettingsProvider);

    final reduceAnimations = settings.reduceAnimations;
    final hideOverlay = viewerSettings.postDetailsOverlayInitialState.isHide;
    final slideshowOptions = toSlideShowOptions(viewerSettings);
    final hoverToControlOverlay = widget.posts[initialPage].isVideo;

    _controller = PostDetailsController<T>(
      scrollController: widget.scrollController,
      initialPage: initialPage,
      initialThumbnailUrl: widget.initialThumbnailUrl,
      posts: _posts,
      reduceAnimations: reduceAnimations,
      dislclaimer: widget.dislclaimer,
      doubleTapSeekDuration: viewerSettings.doubleTapSeekDuration,
    );

    _pageViewController = PostDetailsPageViewController(
      initialPage: initialPage,
      initialHideOverlay: hideOverlay,
      slideshowOptions: slideshowOptions,
      hoverToControlOverlay: hoverToControlOverlay,
      checkIfLargeScreen: () => context.isLargeScreen,
      totalPage: widget.posts.length,
      disableAnimation: reduceAnimations,
      onBeforeSlideshowAdvance: (currentPage, nextPage) async {
        if (viewerSettings.slideshowVideoBehavior.isWaitForCompletion) {
          final currentPost = _posts[currentPage];

          if (currentPost.isVideo) {
            await _controller.waitForVideoCompletion(currentPost.id);
          }
        }
      },
    );

    if (widget.postResolver != null) {
      _controller.currentPage.addListener(_resolveAroundCurrentPage);
      _resolveAroundCurrentPage();
    }
  }

  void _resolveAroundCurrentPage() {
    final page = _controller.currentPage.value;
    [page, page + 1, page - 1].forEach(_resolve);
  }

  Future<void> _resolve(int index) async {
    final resolver = widget.postResolver;
    if (resolver == null || index < 0 || index >= _posts.length) return;
    if (_resolved.contains(index) || _failed.contains(index)) return;
    if (!_inflight.add(index)) return;

    T? post;
    try {
      post = await resolver(_posts[index]);
    } catch (_) {
      post = null;
    } finally {
      _inflight.remove(index);
    }

    if (!mounted) return;

    setState(() {
      switch (post) {
        case final T p:
          _posts[index] = p;
          _resolved.add(index);
          _controller.updateCurrentPost(_controller.currentPage.value);
        case null:
          _failed.add(index);
      }
    });
  }

  void _retryResolve(int index) {
    setState(() => _failed.remove(index));
    _resolve(index);
  }

  PostResolveStatus? _resolveStatusOf(int index) => switch (index) {
    _ when _resolved.contains(index) => null,
    _ when _failed.contains(index) => PostResolveStatus.failed,
    _ => PostResolveStatus.loading,
  };

  @override
  void dispose() {
    _controller.currentPage.removeListener(_resolveAroundCurrentPage);
    _controller.dispose();
    _pageViewController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PostDetailsPageViewScope(
      controller: _pageViewController,
      child: PostDetails(
        data: PostDetailsData(
          posts: _posts,
          controller: _controller,
          resolveStatusOf: widget.postResolver != null
              ? _resolveStatusOf
              : null,
          onRetryResolve: _retryResolve,
        ),
        child: CurrentPostScope(
          post: _controller.currentPost,
          child: widget.child,
        ),
      ),
    );
  }
}

class CurrentPostScope<T extends Post> extends StatelessWidget {
  const CurrentPostScope({
    required this.post,
    required this.child,
    super.key,
  });

  final ValueNotifier<T> post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: post,
      builder: (context, post, _) => InheritedPost<T>(
        post: post,
        child: child,
      ),
    );
  }
}
