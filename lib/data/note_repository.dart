import 'dart:ui' show Color;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'note.dart';
import 'note_category.dart';

/// Stores each note as one plain-text row in a local SQLite database
/// (epad.db in the app's private databases folder), along with the
/// categories notes can belong to.
class NoteRepository {
  /// [factory] and [path] are for tests; the app uses the defaults.
  NoteRepository({DatabaseFactory? factory, String? path})
      : _factory = factory,
        _path = path;

  static final NoteRepository instance = NoteRepository();

  static const int schemaVersion = 2;

  /// Categories created on first run. General (id 1) is the default.
  static const List<(int, String, int)> defaultCategories = [
    (NoteCategory.generalId, 'General', 0xFFFFF176), // yellow
    (2, 'Development', 0xFF90CAF9), // blue
    (3, 'Recipe', 0xFFC5E1A5), // green
    (4, 'Personal', 0xFFF8BBD0), // pink
    (5, 'Work', 0xFFFFCC80), // orange
  ];

  /// Android reads query results through a ~2 MB window per row, so a large
  /// note is read back in pieces. Content is ASCII, so 1 char = 1 byte.
  static const int _readChunk = 512 * 1024;

  final DatabaseFactory? _factory;
  final String? _path;
  Database? _db;
  Future<Database>? _opening;
  List<NoteCategory>? _categoryCache;

  Future<Database> get _database async {
    final db = _db;
    if (db != null) return db;
    return _opening ??= _open().then((db) => _db = db);
  }

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? p.join(await factory.getDatabasesPath(), 'epad.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await createSchemaV1(db);
          await _upgrade(db, 1, version);
        },
        onUpgrade: _upgrade,
      ),
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _opening = null;
    _categoryCache = null;
    await db?.close();
  }

  /// The original (version 1) schema: notes only.
  static Future<void> createSchemaV1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE notes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT    NOT NULL,
        content     TEXT    NOT NULL,
        created_at  INTEGER NOT NULL,
        modified_at INTEGER NOT NULL
      )''');
    await db
        .execute('CREATE INDEX idx_notes_modified ON notes (modified_at DESC)');
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      // Version 2 adds categories. Existing notes become General.
      await db.execute('''
        CREATE TABLE categories (
          id    INTEGER PRIMARY KEY AUTOINCREMENT,
          name  TEXT    NOT NULL UNIQUE COLLATE NOCASE,
          color INTEGER NOT NULL
        )''');
      for (final (id, name, color) in defaultCategories) {
        await db.insert('categories', {'id': id, 'name': name, 'color': color});
      }
      await db.execute('ALTER TABLE notes ADD COLUMN category_id INTEGER '
          'NOT NULL DEFAULT ${NoteCategory.generalId}');
      await db
          .execute('CREATE INDEX idx_notes_category ON notes (category_id)');
    }
  }

  // ---------------------------------------------------------------- notes

  /// Lists notes, newest first. [query] filters by content (case-insensitive);
  /// [categoryId] limits the list to one category.
  Future<List<NoteSummary>> list({String query = '', int? categoryId}) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object>[];
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add("content LIKE ? ESCAPE '\\'");
      args.add('%${_escapeLike(q)}%');
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    final rows = await db.rawQuery(
      'SELECT id, title, substr(content, 1, 200) AS preview, '
      'length(content) AS size, modified_at, category_id FROM notes'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'} '
      'ORDER BY modified_at DESC',
      args,
    );
    return rows.map(NoteSummary.fromRow).toList();
  }

  /// Loads a note's full text, however large, and its category.
  Future<({String content, int categoryId})> loadNote(int id) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT length(content) AS len, category_id FROM notes WHERE id = ?',
        [id]);
    if (rows.isEmpty) throw StateError('Note $id no longer exists.');
    final len = rows.first['len'] as int;
    final buf = StringBuffer();
    for (var start = 1; start <= len; start += _readChunk) {
      final part = await db.rawQuery(
        'SELECT substr(content, ?, ?) AS part FROM notes WHERE id = ?',
        [start, _readChunk, id],
      );
      buf.write(part.first['part'] as String);
    }
    return (
      content: buf.toString(),
      categoryId: rows.first['category_id'] as int,
    );
  }

  Future<int> insert(String content,
      {int categoryId = NoteCategory.generalId}) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('notes', {
      'title': deriveTitle(content),
      'content': content,
      'created_at': now,
      'modified_at': now,
      'category_id': categoryId,
    });
  }

  Future<void> update(int id, String content) async {
    final db = await _database;
    await db.update(
      'notes',
      {
        'title': deriveTitle(content),
        'content': content,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setCategory(int noteId, int categoryId) async {
    final db = await _database;
    await db.update('notes', {'category_id': categoryId},
        where: 'id = ?', whereArgs: [noteId]);
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ----------------------------------------------------------- categories

  /// All categories: General first, then the rest by name.
  Future<List<NoteCategory>> categories() async {
    final cached = _categoryCache;
    if (cached != null) return cached;
    final db = await _database;
    final rows = await db.rawQuery('SELECT id, name, color FROM categories '
        'ORDER BY id = ${NoteCategory.generalId} DESC, name COLLATE NOCASE');
    return _categoryCache = List.unmodifiable(rows.map(NoteCategory.fromRow));
  }

  /// Adds a category. Throws [ArgumentError] if [name] is blank or already
  /// used (ignoring case).
  Future<NoteCategory> addCategory(String name, Color color) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Enter a name.');
    final existing = await categories();
    if (existing.any((c) => c.name.toLowerCase() == clean.toLowerCase())) {
      throw ArgumentError('"$clean" already exists.');
    }
    final db = await _database;
    final id = await db
        .insert('categories', {'name': clean, 'color': color.toARGB32()});
    _categoryCache = null;
    return NoteCategory(id: id, name: clean, color: color);
  }

  /// Deletes a category. Its notes move to General. General can't be deleted.
  Future<void> deleteCategory(int id) async {
    if (id == NoteCategory.generalId) {
      throw ArgumentError('General can\'t be deleted.');
    }
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('notes', {'category_id': NoteCategory.generalId},
          where: 'category_id = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
    _categoryCache = null;
  }

  static String _escapeLike(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}
