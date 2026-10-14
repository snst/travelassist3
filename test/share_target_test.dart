import 'package:flutter_test/flutter_test.dart';
import 'package:travelassist3/utils/shared_content.dart';

void main() {
  group('SharedContent', () {
    test('splits shared text into links and comment, and keeps photo URIs', () {
      final content = SharedContent.fromRaw(
        texts: ['Nice place https://example.com/a'],
        uris: ['content://media/external/images/media/42'],
      );
      expect(content.comment, 'Nice place');
      expect(content.links, [
        'https://example.com/a',
        'content://media/external/images/media/42',
      ]);
    });

    test('appendLinks skips duplicates', () {
      expect(appendLinks('a\tb', ['b', 'c']), 'a\tb\tc');
      expect(appendLinks('', ['c']), 'c');
    });

    test('appendComment appends on a new line', () {
      expect(appendComment('', 'x'), 'x');
      expect(appendComment('a', 'x'), 'a\nx');
      expect(appendComment('a x', 'x'), 'a x');
    });
  });
}
