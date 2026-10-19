import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const _html = '''
<div style="width: 100%;">
  <h5>User Comments</h5>
  <div class="userComment" id="c171673">
    <div style="font-style: italic;"><a href="index.php?page=account&amp;s=profile&amp;uname=alice">alice</a> <span>&raquo; #171673</span></div>
    <div id="c171673" style="display:inline;"><b>Posted on 2026-10-19 04:24:24 Score: <a id="sc171673">3</a> (vote <a href="#">Up</a>)</b></div>
    <div style="font-size: .8em;">First line<br />I&rsquo;m second<br /></div>
  </div>
  <br />
  <div class="userComment" id="c171703">
    <div style="font-style: italic;"><a href="index.php?page=account&amp;s=profile&amp;uname=bob">bob</a></div>
    <div id="c171703" style="display:inline;"><b>Posted on 2026-10-19 07:02:41 Score: <a id="sc171703">0</a></b></div>
    <div style="font-size: .8em;">Hi</div>
  </div>
  <div id="paginator"><b>1</b></div>
</div>
''';

Response<dynamic> _response(Object? data) => Response(
  data: data,
  requestOptions: RequestOptions(),
);

void main() {
  test('extracts every comment with author, date, score and body', () {
    final page = parseRbCommentsHtml(_response(_html), {'post-id': 1012040});

    expect(page.comments.map((c) => c.id), ['171673', '171703']);

    final first = page.comments.first;
    expect(first.creator, 'alice');
    expect(first.createdAt, '2026-10-19 04:24:24');
    expect(first.score, 3);
    expect(first.body, 'First line\nI’m second');
    expect(first.postId, '1012040');
  });

  test('returns no comments for a post page without comments', () {
    final page = parseRbCommentsHtml(_response('<html></html>'), {});
    expect(page.comments, isEmpty);
  });

  test('returns no comments when the response is not html text', () {
    final page = parseRbCommentsHtml(_response(null), {});
    expect(page.comments, isEmpty);
  });
}
