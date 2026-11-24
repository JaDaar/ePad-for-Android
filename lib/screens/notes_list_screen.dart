import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/note.dart';
import '../data/note_category.dart';
import '../data/note_repository.dart';
import '../theme/post_it.dart';
import '../widgets/category_picker.dart';
import '../widgets/help_menu.dart';
import 'editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final _repo = NoteRepository.instance;
  final _search = TextEditingController();
  Timer? _searchDebounce;
  List<NoteSummary> _notes = const [];
  Map<int, NoteCategory> _categories = const {};

  /// The category shown, or null for all.
  int? _filter;
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final cats = await _repo.categories();
      final filter =
          cats.any((c) => c.id == _filter) ? _filter : null; // may be deleted
      final notes = await _repo.list(query: _search.text, categoryId: filter);
      if (!mounted) return;
      setState(() {
        _categories = {for (final c in cats) c.id: c};
        _filter = filter;
        _notes = notes;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notes: $e';
      });
    }
  }

  Future<void> _open(int? id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          noteId: id,
          // While a category is selected, new notes start in it.
          initialCategoryId: _filter ?? NoteCategory.generalId,
        ),
      ),
    );
    await _reload();
  }

  void _setFilter(int? categoryId) {
    setState(() => _filter = categoryId);
    _reload();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching && _search.text.isNotEmpty) {
      _search.clear();
      _reload();
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _reload);
  }

  Future<void> _showNoteActions(NoteSummary note) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Change category'),
              onTap: () => Navigator.pop(context, 'category'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'category') {
      final picked = await pickCategory(context, selectedId: note.categoryId);
      if (picked != null) await _repo.setCategory(note.id, picked.id);
      await _reload();
    } else if (action == 'delete') {
      if (await _confirmDelete(note)) await _delete(note);
    }
  }

  Future<bool> _confirmDelete(NoteSummary note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${note.displayTitle}" will be permanently deleted.'),
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
    return ok ?? false;
  }

  Future<void> _delete(NoteSummary note) async {
    setState(() => _notes = _notes.where((n) => n.id != note.id).toList());
    try {
      await _repo.delete(note.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search notes',
                  border: InputBorder.none,
                ),
              )
            : const Text('ePad'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          const HelpMenuButton(),
        ],
        bottom: _categories.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _buildFilterBar(),
              ),
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New note',
        onPressed: () => _open(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar() {
    Widget chip(String label, int? id, {Color? color}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(label),
            avatar:
                color == null ? null : CategorySwatch(color: color, size: 16),
            selected: _filter == id,
            showCheckmark: false,
            onSelected: (_) => _setFilter(id),
          ),
        );

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        children: [
          chip('All', null),
          for (final c in _categories.values)
            chip(c.name, c.id, color: c.color),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_notes.isEmpty) {
      final filtered = _search.text.isNotEmpty || _filter != null;
      return Center(
        child: Text(
          filtered ? 'No matches.' : 'No notes yet. Tap + to start one.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
      ),
      itemCount: _notes.length,
      itemBuilder: (context, i) {
        final note = _notes[i];
        final category = _categories[note.categoryId];
        return _PostItCard(
          note: note,
          color: category?.color ?? PostIt.yellow,
          caption: category == null
              ? _formatTime(note.modifiedAt)
              : '${category.name}  ·  ${_formatTime(note.modifiedAt)}',
          onTap: () => _open(note.id),
          onLongPress: () => _showNoteActions(note),
        );
      },
    );
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay
        ? '${two(t.hour)}:${two(t.minute)}'
        : '${t.year}-${two(t.month)}-${two(t.day)}';
  }
}

/// One note drawn as a square post-it in its category's color, tilted
/// slightly as if stuck on by hand. The tilt comes from the note id, so it
/// stays the same each time.
class _PostItCard extends StatelessWidget {
  const _PostItCard({
    required this.note,
    required this.color,
    required this.caption,
    required this.onTap,
    required this.onLongPress,
  });

  final NoteSummary note;
  final Color color;
  final String caption;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final angle =
        ((note.id * 37) % 7 - 3) * 0.008; // about -1.4 to +1.4 degrees
    const ink = PostIt.ink;
    return Transform.rotate(
      angle: angle,
      child: Material(
        color: color,
        elevation: 4,
        shadowColor: Colors.black,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 12, color: PostIt.strip(color)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          note.body,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.3,
                            color: ink.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
