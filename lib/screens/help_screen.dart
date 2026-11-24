import 'package:material_ui/material_ui.dart';

import '../widgets/help_menu.dart';

/// A short guide to using ePad.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _sections = <(IconData, String, String)>[
    (
      Icons.add,
      'Write a note',
      'Tap + and start typing. The first line becomes the title. Notes save '
          'as you type, and a note you leave empty is deleted.',
    ),
    (
      Icons.text_fields,
      'Plain text',
      'ePad keeps notes as plain ASCII text with no formatting. Curly quotes, '
          'dashes and "..." from the keyboard become plain ASCII. Emoji and '
          'accented letters are left out.',
    ),
    (
      Icons.label_outline,
      'Categories and colors',
      'Every note has a category, and the category sets its color. New notes '
          'are General (yellow). Change a note\'s category with the label '
          'button in the editor, or long-press the note and choose Change '
          'category.',
    ),
    (
      Icons.new_label_outlined,
      'Your own categories',
      'In the category picker, tap New category to add one with a name and '
          'color. Long-press a category there to delete it; its notes move to '
          'General.',
    ),
    (
      Icons.filter_list,
      'Find notes',
      'Use the chips under the top bar to show one category, or the search '
          'button to find notes containing some text.',
    ),
    (
      Icons.delete_outline,
      'Delete a note',
      'Long-press the note and choose Delete, or use Delete in the editor\'s '
          'menu.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('How to use ePad')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (icon, title, text) in _sections)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(text),
              ),
              isThreeLine: true,
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '$appName  ·  $copyright',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
