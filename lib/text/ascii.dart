import 'package:flutter/services.dart';

/// Characters ePad keeps: printable ASCII (0x20-0x7E), tab and line feed.
bool _isAllowed(int c) => c == 0x0A || c == 0x09 || (c >= 0x20 && c <= 0x7E);

/// Common non-ASCII characters that phone keyboards insert, mapped to plain
/// ASCII so the user's intent survives. Anything else non-ASCII is dropped.
const Map<int, String> _replacements = {
  0x00A0: ' ', 0x2002: ' ', 0x2003: ' ', 0x2009: ' ', 0x202F: ' ', // spaces
  0x2018: "'", 0x2019: "'", 0x201A: "'", 0x201B: "'",
  0x2032: "'", // single quotes
  0x201C: '"', 0x201D: '"', 0x201E: '"', 0x201F: '"',
  0x2033: '"', // double quotes
  0x2010: '-', 0x2011: '-', 0x2012: '-', 0x2013: '-', 0x2014: '-', // dashes
  0x2015: '-', 0x2212: '-',
  0x2026: '...', // ellipsis
  0x2022: '*', // bullet
  0x00AB: '<<', 0x00BB: '>>', 0x2039: '<', 0x203A: '>',
  0x00D7: 'x',
};

/// True when [s] contains only characters ePad allows.
bool isAsciiText(String s) {
  for (final c in s.codeUnits) {
    if (!_isAllowed(c)) return false;
  }
  return true;
}

/// Converts [input] to plain ASCII: CRLF and CR become LF, known typographic
/// characters are transliterated, and all other non-ASCII is removed.
String toAscii(String input) {
  if (isAsciiText(input)) return input;
  final out = StringBuffer();
  var prev = -1;
  for (final r in input.runes) {
    if (r == 0x0D) {
      out.writeCharCode(0x0A);
    } else if (r == 0x0A) {
      if (prev != 0x0D) out.writeCharCode(0x0A);
    } else if (_isAllowed(r)) {
      out.writeCharCode(r);
    } else {
      final rep = _replacements[r];
      if (rep != null) out.write(rep);
    }
    prev = r;
  }
  return out.toString();
}

/// Keeps a text field ASCII-only as the user types or pastes, keeping the
/// cursor where the user expects it.
class AsciiTextInputFormatter extends TextInputFormatter {
  const AsciiTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (isAsciiText(text)) return newValue;

    int mapOffset(int offset) {
      if (offset < 0) return offset;
      final end = offset > text.length ? text.length : offset;
      return toAscii(text.substring(0, end)).length;
    }

    final sel = newValue.selection;
    return TextEditingValue(
      text: toAscii(text),
      selection: sel.copyWith(
        baseOffset: mapOffset(sel.baseOffset),
        extentOffset: mapOffset(sel.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }
}
