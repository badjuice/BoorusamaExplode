// Package imports:
import 'package:path/path.dart' as p;

enum DownloadMediaKind { image, gif, video }

/// Builds the subfolder (relative to the download location) a file goes in,
/// or null when every grouping option is off.
String? downloadSubfolder({
  required bool bySite,
  required bool bySearch,
  required bool byMediaType,
  required String siteUrl,
  required String? searchQuery,
  required DownloadMediaKind mediaKind,
}) {
  final segments = [
    if (bySite) ?_folderName(Uri.tryParse(siteUrl)?.host),
    if (bySearch) ?_folderName(searchQuery),
    if (byMediaType)
      switch (mediaKind) {
        DownloadMediaKind.image => 'images',
        DownloadMediaKind.gif => 'gifs',
        DownloadMediaKind.video => 'videos',
      },
  ];

  return segments.isEmpty ? null : p.joinAll(segments);
}

final _invalidChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
const _maxFolderNameLength = 80;

String? _folderName(String? value) {
  final cleaned = value
      ?.trim()
      .replaceAll(_invalidChars, '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^\.+|\.+$'), '');

  return switch (cleaned) {
    null || '' => null,
    final name when name.length > _maxFolderNameLength => name.substring(
      0,
      _maxFolderNameLength,
    ),
    final name => name,
  };
}
