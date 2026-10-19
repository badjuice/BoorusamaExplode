// Package imports:
import 'package:equatable/equatable.dart';

typedef DownloadedPostKey = ({String siteUrl, int postId});

enum PostDownloadStatus { none, pending, downloaded }

class DownloadedPost extends Equatable {
  const DownloadedPost({
    required this.siteUrl,
    required this.postId,
    required this.downloadedAt,
    this.filePath,
  });

  final String siteUrl;
  final int postId;
  final DateTime downloadedAt;
  final String? filePath;

  DownloadedPostKey get key => (siteUrl: siteUrl, postId: postId);

  @override
  List<Object?> get props => [siteUrl, postId, downloadedAt, filePath];
}

abstract interface class DownloadedPostRepository {
  Future<Set<DownloadedPostKey>> getAllKeys();
  Future<void> add(DownloadedPost post);
  Future<void> remove(DownloadedPostKey key);
}

class InMemoryDownloadedPostRepository implements DownloadedPostRepository {
  final _posts = <DownloadedPostKey, DownloadedPost>{};

  @override
  Future<Set<DownloadedPostKey>> getAllKeys() async => _posts.keys.toSet();

  @override
  Future<void> add(DownloadedPost post) async => _posts[post.key] = post;

  @override
  Future<void> remove(DownloadedPostKey key) async => _posts.remove(key);
}

class DownloadHistoryState extends Equatable {
  const DownloadHistoryState({
    required this.downloaded,
    required this.pending,
  });

  static const empty = DownloadHistoryState(downloaded: {}, pending: {});

  final Set<DownloadedPostKey> downloaded;
  final Set<DownloadedPostKey> pending;

  PostDownloadStatus statusOf(DownloadedPostKey key) => switch (key) {
    _ when downloaded.contains(key) => PostDownloadStatus.downloaded,
    _ when pending.contains(key) => PostDownloadStatus.pending,
    _ => PostDownloadStatus.none,
  };

  DownloadHistoryState copyWith({
    Set<DownloadedPostKey>? downloaded,
    Set<DownloadedPostKey>? pending,
  }) => DownloadHistoryState(
    downloaded: downloaded ?? this.downloaded,
    pending: pending ?? this.pending,
  );

  @override
  List<Object?> get props => [downloaded, pending];
}
