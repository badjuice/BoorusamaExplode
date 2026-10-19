// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show join;

// Project imports:
import '../../../../foundation/database/utils.dart';
import '../../../../foundation/filesystem.dart';
import '../../../../foundation/loggers.dart';
import '../types.dart';
import 'repo_sqlite.dart';

const _kDbName = 'downloaded_posts.db';

final downloadedPostRepoProvider = FutureProvider<DownloadedPostRepository>((
  ref,
) async {
  final fs = ref.watch(appFileSystemProvider);
  final logger = ref.watch(loggerProvider);
  final db = await createDb(
    fs: fs,
    folderPath: join(await fs.getAppStoragePath(), 'data'),
    name: _kDbName,
    logger: logger,
  );

  if (db == null) return InMemoryDownloadedPostRepository();

  try {
    final repo = DownloadedPostRepositorySqlite(db: db)..initialize();
    ref.onDispose(repo.close);
    return repo;
  } on Exception catch (e) {
    logger.error('Download History', 'Failed to initialize database: $e');
    db.close();
    return InMemoryDownloadedPostRepository();
  }
});
