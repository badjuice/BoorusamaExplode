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

  for (final c in cases) {
    test('post ${c.id} gets a ${c.ext} file url and underscored tags', () {
      final post = posts.firstWhere((p) => p.id == c.id);
      expect(post.fileUrl, endsWith(c.ext));
      expect(post.fileUrl, contains('/images/aa/bb/'));
      expect(post.tags, c.tags);
    });
  }
}
