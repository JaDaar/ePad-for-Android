import 'package:material_ui/material_ui.dart';

import '../data/note_category.dart';
import '../data/note_repository.dart';
import '../text/ascii.dart';
import '../theme/post_it.dart';

/// Shows a bottom sheet for choosing a note's category, where categories can
/// also be created or deleted. Returns the chosen category, or null if the
/// sheet was dismissed. Callers should re-read categories afterwards, since
/// one may have been deleted.
Future<NoteCategory?> pickCategory(BuildContext context,
    {required int selectedId}) {
  return showModalBottomSheet<NoteCategory>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _CategorySheet(selectedId: selectedId),
  );
}

/// A small square of [color], drawn like a tiny post-it.
class CategorySwatch extends StatelessWidget {
  const CategorySwatch({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.selectedId});

  final int selectedId;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _repo = NoteRepository.instance;
  List<NoteCategory>? _categories;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final cats = await _repo.categories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _create() async {
    final created = await showDialog<NoteCategory>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (created != null && mounted) Navigator.pop(context, created);
  }

  Future<void> _delete(NoteCategory category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text('Notes in this category will move to General.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteCategory(category.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories;
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Category', style: theme.textTheme.titleMedium),
          ),
          if (cats == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in cats)
                    ListTile(
                      leading: CategorySwatch(color: c.color),
                      title: Text(c.name),
                      trailing: c.id == widget.selectedId
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, c),
                      onLongPress: c.isGeneral ? null : () => _delete(c),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New category'),
                    onTap: _create,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              'Long-press a category to delete it.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _name = TextEditingController();
  Color _color = PostIt.palette[1];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final created =
          await NoteRepository.instance.addCategory(_name.text, _color);
      if (mounted) Navigator.pop(context, created);
    } on ArgumentError catch (e) {
      setState(() {
        _error = '${e.message}';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [AsciiTextInputFormatter()],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in PostIt.palette)
                InkResponse(
                  onTap: () => setState(() => _color = color),
                  radius: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CategorySwatch(color: color, size: 40),
                      if (color == _color)
                        const Icon(Icons.check, color: PostIt.ink),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
