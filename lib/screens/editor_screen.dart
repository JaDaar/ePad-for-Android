import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../data/note.dart';
import '../data/note_category.dart';
import '../data/note_repository.dart';
import '../text/ascii.dart';
import '../theme/post_it.dart';
import '../widgets/category_picker.dart';

/// Plain-text editor on note paper colored by the note's category. Saves
/// automatically while typing, when the app goes to the background, and on
/// leaving. A note left empty is deleted.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.noteId,
    this.initialCategoryId = NoteCategory.generalId,
  });

  /// The note to open, or null to start a new one.
  final int? noteId;

  /// The category a new note starts in.
  final int initialCategoryId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  final _repo = NoteRepository.instance;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  Future<void> _saveChain = Future.value();
  int? _id;
  late int _categoryId;
  List<NoteCategory> _categories = const [];
  String _savedText = '';
  bool _loading = true;
  bool _deleted = false;
  bool _closing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = widget.noteId;
    _categoryId = widget.initialCategoryId;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    if (!_loading && !_deleted && _controller.text != _savedText) {
      unawaited(_save());
    }
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _save();
    }
  }

  Future<void> _load() async {
    final id = _id;
    try {
      _categories = await _repo.categories();
      if (id != null) {
        final note = await _repo.loadNote(id);
        _categoryId = note.categoryId;
        _savedText = note.content;
        _controller.value = TextEditingValue(
          text: toAscii(note.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (e) {
      _error = 'Could not open note: $e';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _controller.addListener(_onChanged);
    if (id == null) _focus.requestFocus();
  }

  void _onChanged() {
    if (_controller.text == _savedText) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _save);
  }

  /// Queues a save of the current text. Saves run one at a time, so a new
  /// note is only ever inserted once.
  Future<void> _save() {
    _debounce?.cancel();
    if (_loading || _error != null) return _saveChain;
    final text = _controller.text;
    return _saveChain = _saveChain.then((_) => _write(text));
  }

  Future<void> _write(String text) async {
    if (_deleted || text == _savedText) return;
    try {
      final id = _id;
      if (id == null) {
        if (text.trim().isEmpty) return;
        _id = await _repo.insert(text, categoryId: _categoryId);
      } else {
        await _repo.update(id, text);
      }
      _savedText = text;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _save();
    final id = _id;
    if (id != null && !_deleted && _controller.text.trim().isEmpty) {
      _deleted = true;
      await _repo.delete(id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteNote() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be permanently deleted.'),
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
    _debounce?.cancel();
    _deleted = true;
    _closing = true;
    await _saveChain;
    final id = _id;
    if (id != null) await _repo.delete(id);
    if (mounted) Navigator.of(context).pop();
  }

  NoteCategory get _category => _categories.firstWhere(
        (c) => c.id == _categoryId,
        orElse: () => const NoteCategory(
          id: NoteCategory.generalId,
          name: 'General',
          color: PostIt.yellow,
        ),
      );

  Future<void> _chooseCategory() async {
    final picked = await pickCategory(context, selectedId: _categoryId);
    // Re-read: a category (maybe this note's) may have been deleted.
    final cats = await _repo.categories();
    var newId = picked?.id ?? _categoryId;
    if (!cats.any((c) => c.id == newId)) newId = NoteCategory.generalId;
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _categoryId = newId;
    });
    // Queued behind any pending save, so a note still being inserted gets
    // the new category too.
    _saveChain = _saveChain.then((_) async {
      final id = _id;
      if (id != null && !_deleted) await _repo.setCategory(id, newId);
    });
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AnimatedTheme(
        data: PostIt.theme(category.color),
        child: Scaffold(
          appBar: AppBar(
            title: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final title = deriveTitle(value.text);
                return Text(
                  title.isEmpty
                      ? (_id == null ? 'New note' : 'Untitled')
                      : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            actions: [
              TextButton.icon(
                onPressed: _loading || _error != null ? null : _chooseCategory,
                style: TextButton.styleFrom(foregroundColor: PostIt.ink),
                icon: const Icon(Icons.label_outline),
                label: Text(category.name),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'copy') _copyAll();
                  if (v == 'delete') _deleteNote();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'copy', child: Text('Copy all')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: Builder(builder: _buildBody),
        ),
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
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              autocorrect: false,
              smartQuotesType: SmartQuotesType.disabled,
              smartDashesType: SmartDashesType.disabled,
              inputFormatters: const [AsciiTextInputFormatter()],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                height: 1.35,
                color: PostIt.ink,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                hintText: 'Start typing...',
                hintStyle: TextStyle(color: PostIt.ink.withValues(alpha: 0.45)),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: PostIt.strip(theme.scaffoldBackgroundColor),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => Text(
                _status(value),
                style: theme.textTheme.bodySmall?.copyWith(color: PostIt.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _status(TextEditingValue v) {
    final text = v.text;
    final offset = v.selection.baseOffset.clamp(0, text.length);
    var line = 1;
    var lastNewline = -1;
    for (var i = 0; i < offset; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        line++;
        lastNewline = i;
      }
    }
    return 'Ln $line, Col ${offset - lastNewline}   ·   ${text.length} chars';
  }
}
