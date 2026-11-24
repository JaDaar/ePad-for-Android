import 'package:material_ui/material_ui.dart';

/// The sticky-note look shared by the notes grid and the editor.
abstract final class PostIt {
  /// The classic post-it yellow, used by the General category.
  static const Color yellow = Color(0xFFFFF176);
  static const Color blue = Color(0xFF90CAF9);
  static const Color green = Color(0xFFC5E1A5);
  static const Color pink = Color(0xFFF8BBD0);
  static const Color orange = Color(0xFFFFCC80);
  static const Color purple = Color(0xFFD1C4E9);
  static const Color teal = Color(0xFFB2DFDB);
  static const Color grey = Color(0xFFE0E0E0);

  /// Colors offered when creating a category.
  static const List<Color> palette = [
    yellow, blue, green, pink, orange, purple, teal, grey, //
  ];

  /// Dark "ink" that reads well on every palette color.
  static const Color ink = Color(0xFF332E1F);

  /// The slightly darker glue strip across the top of a note of [paper] color.
  static Color strip(Color paper) {
    final hsl = HSLColor.fromColor(paper);
    return hsl.withLightness((hsl.lightness - 0.07).clamp(0.0, 1.0)).toColor();
  }

  /// Theme for a screen drawn on note paper of [paper] color (the editor).
  /// Always light: a post-it keeps its color whatever the system theme is.
  static ThemeData theme(Color paper) {
    final base =
        ThemeData(colorSchemeSeed: paper, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ink,
        selectionColor: ink.withValues(alpha: 0.25),
        selectionHandleColor: ink,
      ),
    );
  }
}
