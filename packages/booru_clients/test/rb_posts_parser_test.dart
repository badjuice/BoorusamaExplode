import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

String _thumb(int id, String hash, String title, {String style = ''}) =>
    '<div class="col thumb" id="s$id"><a id="p$id" href="index.php?page=post&amp;s=view&amp;id=$id">'
    '<img src="https://realbooru.com/thumbnails/${hash.substring(0, 2)}/${hash.substring(2, 4)}/thumbnail_$hash.jpg" '
    'title="$title" alt="Image: $id" style="$style"/></a></div>';

final _html =
    '<div class="items">'
    '${_thumb(1, 'aabb0000000000000000000000000001', 'tagme, webm', style: 'border: 3px solid #0000ff;')}'
    '${_thumb(2, 'aabb0000000000000000000000000002', 'amateur, animated, animated gif, big ass')}'
    '${_thumb(3, 'aabb0000000000000000000000000003', '1girl, female focus, high heels')}'
    '</div>';

void main() {
  final posts = parseRbPostsHtml(
    Response(data: _html, requestOptions: RequestOptions()),
    {},
  ).posts;

  final cases = [
    (id: 1, ext: '.mp4', tags: 'tagme webm'),
    (id: 2, ext: '.gif', tags: 'amateur animated animated_gif big_ass'),
    (id: 3, ext: '.jpg', tags: '1girl female_focus high_heels'),
  ];

  test('reads tag types and global counts from the search sidebar', () {
    const sidebar =
        '<div class="all-tag-container-view">'
        '<li class="tag-type-copyright"><a href="#">twitter</a> 5107</li>'
        '<li class="tag-type-metadata"><a href="#">vertical video</a> 6891</li>'
        '<li class="tag-type-general"><a href="#">redhead</a> 3998</li>'
        '</div>';

    final tags = parseRbTagsHtml(
      Response(data: sidebar, requestOptions: RequestOptions()),
      {},
    );

    expect(
      tags.map((t) => (t.name, t.type, t.count)),
      [
        ('twitter', 3, 5107),
        ('vertical_video', 5, 6891),
        ('redhead', 0, 3998),
      ],
    );
  });

  for (final c in cases) {
    test('post ${c.id} gets a ${c.ext} file url and underscored tags', () {
      final post = posts.firstWhere((p) => p.id == c.id);
      expect(post.fileUrl, endsWith(c.ext));
      expect(post.fileUrl, contains('/images/aa/bb/'));
      expect(post.tags, c.tags);
    });
  }
}
