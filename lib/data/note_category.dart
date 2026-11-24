import 'dart:ui' show Color;

/// A label such as General, Development or Recipe. Each category has its own
/// post-it color.
class NoteCategory {
  const NoteCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  factory NoteCategory.fromRow(Map<String, Object?> row) => NoteCategory(
        id: row['id'] as int,
        name: row['name'] as String,
        color: Color(row['color'] as int),
      );

  /// General is the default category. It always exists and can't be deleted.
  static const int generalId = 1;

  final int id;
  final String name;
  final Color color;

  bool get isGeneral => id == generalId;
}
