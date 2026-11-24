import 'package:epad/data/note.dart';
import 'package:epad/text/ascii.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toAscii', () {
    test('leaves plain ASCII untouched', () {
      const s = 'Hello, world!\n\tTabbed ~ 123';
      expect(identical(toAscii(s), s), isTrue);
    });

    test('transliterates smart punctuation', () {
      expect(toAscii('“Hi” — it’s…'), '"Hi" - it\'s...');
    });

    test('normalises line endings', () {
      expect(toAscii('a\r\nb\rc\n'), 'a\nb\nc\n');
    });

    test('drops other non-ASCII, including emoji', () {
      expect(toAscii('café \u{1F600}!'), 'caf !');
    });
  });

  group('AsciiTextInputFormatter', () {
    const f = AsciiTextInputFormatter();

    test('keeps cursor after an expanded ellipsis', () {
      final out = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'wait…',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(out.text, 'wait...');
      expect(out.selection.baseOffset, 7);
    });

    test('keeps cursor after a removed emoji', () {
      final out = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'a\u{1F600}b',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(out.text, 'ab');
      expect(out.selection.baseOffset, 1);
    });
  });

  group('deriveTitle', () {
    test('uses the first non-blank line', () {
      expect(deriveTitle('\n   \n  Shopping list  \nmilk'), 'Shopping list');
    });

    test('is empty for blank text', () {
      expect(deriveTitle(' \n\t\n'), '');
    });

    test('is capped in length', () {
      expect(deriveTitle('x' * 500).length, maxTitleLength);
    });
  });
}
