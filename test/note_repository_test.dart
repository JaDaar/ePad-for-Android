import 'dart:io';

import 'package:epad/data/note_category.dart';
import 'package:epad/data/note_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  late Directory dir;
  late NoteRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('epad_test');
    repo = NoteRepository(factory: factory, path: p.join(dir.path, 'epad.db'));
  });

  tearDown(() async {
    await repo.close();
    dir.deleteSync(recursive: true);
  });

  test('fresh database has default categories, General first', () async {
    final cats = await repo.categories();
    expect(cats.first.name, 'General');
    expect(cats.first.id, NoteCategory.generalId);
    expect(cats.first.color, const Color(0xFFFFF176));
    expect(cats.map((c) => c.name),
        containsAll(['Development', 'Recipe', 'Personal', 'Work']));
  });

  test('new notes default to General', () async {
    final id = await repo.insert('hello');
    expect((await repo.loadNote(id)).categoryId, NoteCategory.generalId);
  });

  test('upgrading a version 1 database keeps notes, as General', () async {
    final path = p.join(dir.path, 'old.db');
    final old = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) => NoteRepository.createSchemaV1(db)));
    await old.insert('notes', {
      'title': 'Old',
      'content': 'Old\nnote',
      'created_at': 1,
      'modified_at': 1,
    });
    await old.close();

    final upgraded = NoteRepository(factory: factory, path: path);
    final notes = await upgraded.list();
    expect(notes.single.title, 'Old');
    expect(notes.single.categoryId, NoteCategory.generalId);
    expect((await upgraded.loadNote(notes.single.id)).content, 'Old\nnote');
    expect((await upgraded.categories()).length, 5);
    await upgraded.close();
  });

  test('set category, filter by it, and delete it', () async {
    final recipe =
        (await repo.categories()).firstWhere((c) => c.name == 'Recipe');
    final soup = await repo.insert('Soup', categoryId: recipe.id);
    await repo.insert('Other');

    expect((await repo.list(categoryId: recipe.id)).single.id, soup);

    await repo.deleteCategory(recipe.id);
    expect((await repo.categories()).any((c) => c.id == recipe.id), isFalse);
    expect((await repo.loadNote(soup)).categoryId, NoteCategory.generalId);
  });

  test('custom categories: added, and names are unique ignoring case',
      () async {
    final travel = await repo.addCategory(' Travel ', const Color(0xFFB2DFDB));
    expect(travel.name, 'Travel');
    expect((await repo.categories()).any((c) => c.id == travel.id), isTrue);
    expect(() => repo.addCategory('travel', const Color(0xFFE0E0E0)),
        throwsArgumentError);
    expect(() => repo.addCategory('  ', const Color(0xFFE0E0E0)),
        throwsArgumentError);
  });

  test('General cannot be deleted', () {
    expect(
        () => repo.deleteCategory(NoteCategory.generalId), throwsArgumentError);
  });

  test('large notes load back intact', () async {
    final big =
        List.generate(150000, (i) => 'line $i of a big note').join('\n');
    expect(big.length, greaterThan(1024 * 1024));
    final id = await repo.insert(big);
    expect((await repo.loadNote(id)).content, big);
  });
}
