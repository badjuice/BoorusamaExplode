// Package imports:
import 'package:sqlite3/sqlite3.dart';

// Project imports:
import '../types.dart';

const _kTable = 'downloaded_posts';

class DownloadedPostRepositorySqlite implements DownloadedPostRepository {
  DownloadedPostRepositorySqlite({required this.db});

  final Database db;

  void close() => db.close();

  void initialize() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_kTable (
        site_url TEXT NOT NULL,
        post_id INTEGER NOT NULL,
        file_path TEXT,
        thumbnail_url TEXT,
        is_video INTEGER NOT NULL DEFAULT 0,
        downloaded_at INTEGER NOT NULL,
        PRIMARY KEY (site_url, post_id)
      );
    ''');
  }

  @override
  Future<Set<DownloadedPostKey>> getAllKeys() async {
    final rows = db.select('SELECT site_url, post_id FROM $_kTable');

    return {
      for (final row in rows)
        if ((row['site_url'], row['post_id']) case (
          final String siteUrl,
          final int postId,
        ))
          (siteUrl: siteUrl, postId: postId),
    };
  }

  @override
  Future<List<DownloadedPost>> getAll() async {
    final rows = db.select(
      'SELECT * FROM $_kTable ORDER BY downloaded_at DESC',
    );

    return [
      for (final row in rows)
        if ((row['site_url'], row['post_id'], row['downloaded_at']) case (
          final String siteUrl,
          final int postId,
          final int downloadedAt,
        ))
          DownloadedPost(
            siteUrl: siteUrl,
            postId: postId,
            downloadedAt: DateTime.fromMillisecondsSinceEpoch(downloadedAt),
            filePath: row['file_path'] as String?,
            thumbnailUrl: row['thumbnail_url'] as String?,
            isVideo: row['is_video'] == 1,
          ),
    ];
  }

  @override
  Future<void> add(DownloadedPost post) async {
    db.execute(
      'INSERT OR REPLACE INTO $_kTable '
      '(site_url, post_id, file_path, thumbnail_url, is_video, downloaded_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        post.siteUrl,
        post.postId,
        post.filePath,
        post.thumbnailUrl,
        if (post.isVideo) 1 else 0,
        post.downloadedAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> remove(DownloadedPostKey key) async {
    db.execute(
      'DELETE FROM $_kTable WHERE site_url = ? AND post_id = ?',
      [key.siteUrl, key.postId],
    );
  }
}
