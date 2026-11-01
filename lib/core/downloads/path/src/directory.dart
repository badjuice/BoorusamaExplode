// Project imports:
import '../../../../foundation/filesystem.dart';
import '../../../../foundation/platform.dart';

/// Shared folders need no storage permission on Android 10 and later, and
/// gallery apps list this one as an album.
const kDefaultAndroidDownloadPath =
    '/storage/emulated/0/Pictures/BoorusamaExplode';

sealed class DownloadDirectoryResult {
  const DownloadDirectoryResult();
}

final class DownloadDirectorySuccess extends DownloadDirectoryResult {
  const DownloadDirectorySuccess(this.path);

  final String path;
}

final class DownloadDirectoryFailure extends DownloadDirectoryResult {
  const DownloadDirectoryFailure([this.message]);

  final String? message;
}

Future<DownloadDirectoryResult> tryGetDownloadDirectory(
  AppFileSystem fs,
) async {
  if (isAndroid()) {
    try {
      if (!fs.directoryExistsSync(kDefaultAndroidDownloadPath)) {
        await fs.createDirectory(kDefaultAndroidDownloadPath, recursive: true);
      }
      return const DownloadDirectorySuccess(kDefaultAndroidDownloadPath);
    } catch (_) {
      // Fall back to the system download folder below.
    }
  }

  final path = await fs.getDownloadPath();
  if (path == null) {
    return const DownloadDirectoryFailure('Download directory not available');
  }
  return DownloadDirectorySuccess(path);
}

Future<DownloadDirectoryResult> tryGetCustomDownloadDirectory(
  AppFileSystem fs,
  String path,
) async {
  try {
    if (!fs.directoryExistsSync(path)) {
      return const DownloadDirectoryFailure('Directory not found');
    }
    return DownloadDirectorySuccess(path);
  } catch (e) {
    return DownloadDirectoryFailure(e.toString());
  }
}
