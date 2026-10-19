// Package imports:
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../settings/types.dart';
import '../../../post/types.dart';
import '../../../slideshow/types.dart';
import '../widgets/post_details_controller.dart';

enum PostResolveStatus { loading, failed }

class PostDetailsData<T extends Post> {
  const PostDetailsData({
    required this.posts,
    required this.controller,
    this.resolveStatusOf,
    this.onRetryResolve,
  });

  final List<T> posts;
  final PostDetailsController<T> controller;

  /// Non-null while the post at an index is still a partial listing entry
  /// whose full data has to be fetched before it can be shown.
  final PostResolveStatus? Function(int index)? resolveStatusOf;
  final void Function(int index)? onRetryResolve;
}

class PostDetails<T extends Post> extends InheritedWidget {
  const PostDetails({
    required this.data,
    required super.child,
    super.key,
  });

  final PostDetailsData<T> data;

  static PostDetailsData<T> of<T extends Post>(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<PostDetails<T>>();
    return widget?.data ?? (throw Exception('No PostDetails found in context'));
  }

  static PostDetailsData<T>? maybeOf<T extends Post>(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<PostDetails<T>>();

    return widget?.data;
  }

  @override
  bool updateShouldNotify(PostDetails<T> oldWidget) {
    return data != oldWidget.data;
  }
}

SlideshowOptions toSlideShowOptions(ImageViewerSettings viewerSettings) {
  final interval = viewerSettings.slideshowInterval;
  final duration = interval < 1
      ? Duration(
          milliseconds: (interval * 1000).toInt(),
        )
      : Duration(seconds: interval.toInt());

  return SlideshowOptions(
    duration: duration,
    direction: viewerSettings.slideshowDirection,
    skipTransition: viewerSettings.slideshowTransitionType.isSkip,
  );
}
