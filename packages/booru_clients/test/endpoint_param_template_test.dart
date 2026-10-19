import 'package:booru_clients/core.dart';
import 'package:test/test.dart';

void main() {
  Endpoint<void> endpoint(Map<String, String> userParams) => Endpoint(
    featureId: BooruFeatureId.tags,
    path: '/index.php?page=post&s=list',
    parser: (_, _) {},
    userParams: userParams,
  );

  final cases = [
    (mapping: {'post-id': 'id'}, expected: {'id': '7'}),
    (mapping: {'post-id': 'tags=id:{}'}, expected: {'tags': 'id:7'}),
    (mapping: <String, String>{}, expected: {'post-id': '7'}),
  ];

  for (final c in cases) {
    test('maps post-id with ${c.mapping} to ${c.expected}', () {
      final url = endpoint(
        c.mapping,
      ).buildUrl('https://example.com/', {'post-id': '7'});

      expect(
        Uri.parse(url).queryParameters,
        {'page': 'post', 's': 'list', ...c.expected},
      );
    });
  }
}
