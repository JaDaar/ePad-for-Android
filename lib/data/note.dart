/// A row in the notes list. Holds only a preview, never the full content,
/// so very large notes don't slow the list down.
class NoteSummary {
  const NoteSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.length,
    required this.modifiedAt,
    required this.categoryId,
  });

  factory NoteSummary.fromRow(Map<String, Object?> row) => NoteSummary(
        id: row['id'] as int,
        title: row['title'] as String,
        preview: (row['preview'] as String?) ?? '',
        length: (row['size'] as int?) ?? 0,
        modifiedAt:
            DateTime.fromMillisecondsSinceEpoch(row['modified_at'] as int),
        categoryId: row['category_id'] as int,
      );

  final int id;
  final String title;
  final String preview;
  final int length;
  final DateTime modifiedAt;
  final int categoryId;

  String get displayTitle => title.isEmpty ? 'Untitled' : title;

  /// The start of the text after the title, line breaks kept, for the note card.
  String get body {
    var text = preview.trimLeft();
    if (title.isNotEmpty && text.startsWith(title)) {
      text = text.substring(title.length);
    }
    return text.trim();
  }
}

const int maxTitleLength = 80;

/// A note's title is its first non-blank line, cut to [maxTitleLength].
String deriveTitle(String content) {
  var start = 0;
  while (start < content.length) {
    var end = content.indexOf('\n', start);
    if (end == -1) end = content.length;
    final line = content.substring(start, end).trim();
    if (line.isNotEmpty) {
      return line.length > maxTitleLength
          ? line.substring(0, maxTitleLength)
          : line;
    }
    start = end + 1;
  }
  return '';
}
