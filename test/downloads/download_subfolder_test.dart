// Package imports:
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/downloads/organization/types.dart';

void main() {
  String? folder({
    bool bySite = false,
    bool bySearch = false,
    bool byMediaType = false,
    String? query,
    DownloadMediaKind kind = DownloadMediaKind.image,
  }) => downloadSubfolder(
    bySite: bySite,
    bySearch: bySearch,
    byMediaType: byMediaType,
    siteUrl: 'https://realbooru.com/',
    searchQuery: query,
    mediaKind: kind,
  );

  final cases = [
    (name: 'all off', result: folder(), expected: null),
    (
      name: 'site only',
      result: folder(bySite: true),
      expected: 'realbooru.com',
    ),
    (
      name: 'site, search and type nested in order',
      result: folder(
        bySite: true,
        bySearch: true,
        byMediaType: true,
        query: 'redhead solo',
        kind: DownloadMediaKind.video,
      ),
      expected: p.join('realbooru.com', 'redhead solo', 'videos'),
    ),
    (
      name: 'search level skipped without an active search',
      result: folder(bySite: true, bySearch: true),
      expected: 'realbooru.com',
    ),
    (
      name: 'characters invalid in folder names are replaced',
      result: folder(bySearch: true, query: 'rating:explicit score:>10'),
      expected: 'rating_explicit score__10',
    ),
    (
      name: 'gifs get their own folder',
      result: folder(byMediaType: true, kind: DownloadMediaKind.gif),
      expected: 'gifs',
    ),
  ];

  for (final c in cases) {
    test('${c.name} gives ${c.expected}', () {
      expect(c.result, c.expected);
    });
  }
}
