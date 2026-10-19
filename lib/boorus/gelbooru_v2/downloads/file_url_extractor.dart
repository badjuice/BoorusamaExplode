// Dart imports:
import 'dart:async';

// Package imports:
import 'package:booru_clients/gelbooru.dart';

// Project imports:
import '../../../core/downloads/urls/types.dart';
import '../../../core/posts/post/types.dart';
import '../../../foundation/caching.dart';

// Listing pages of thumbnail-only sites only expose a thumbnail, so the file
// url is a guess that is often wrong (extension differs, e.g. .mp4 or .jpeg).
// The post page has the real url.
class GelbooruV2ThumbnailOnlyDownloadFileUrlExtractor
    implements DownloadFileUrlExtractor {
  GelbooruV2ThumbnailOnlyDownloadFileUrlExtractor({
    required this.client,
  });

  final GelbooruV2Client client;
  final Cache<String> cache = Cache(
    maxCapacity: 500,
    staleDuration: const Duration(minutes: 30),
  );
  final _pendingRequests = <int, Future<String?>>{};

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    if (quality == 'preview' && post.thumbnailImageUrl.isNotEmpty) {
      return DownloadUrlData.urlOnly(post.thumbnailImageUrl);
    }

    final url = await _getFileUrl(post.id);

    return url != null ? DownloadUrlData.urlOnly(url) : null;
  }

  Future<String?> _getFileUrl(int postId) async {
    final cached = cache.get(postId.toString());
    if (cached != null) return cached;

    final pending = _pendingRequests[postId];
    if (pending != null) return pending;

    final request = _fetchAndCache(postId);
    _pendingRequests[postId] = request;

    try {
      return await request;
    } finally {
      if (identical(_pendingRequests[postId], request)) {
        unawaited(_pendingRequests.remove(postId));
      }
    }
  }

  Future<String?> _fetchAndCache(int postId) async {
    final post = await client.getPost(postId);
    final url = switch (post?.fileUrl) {
      final String url when url.isNotEmpty => url,
      _ => null,
    };

    if (url != null) cache.set(postId.toString(), url);

    return url;
  }
}
