import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:postmark/data/stamp_paths.dart';
import 'package:postmark/data/stamp_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Bytes only need to be distinguishable on disk; the store never decodes them.
final _bytes = Uint8List.fromList([1, 2, 3, 4]);

void main() {
  // sqflite targets mobile; ffi provides a real SQLite for the Dart VM.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('postmark_test');
  });

  tearDown(() async {
    if (docs.existsSync()) await docs.delete(recursive: true);
  });

  /// Opens a store over the shared temp directory, as a fresh app launch would.
  Future<StampStore> openStore() async {
    final store = StampStore(StampPaths(docs));
    await store.open();
    return store;
  }

  test('save returns a stamp and writes its image to disk', () async {
    final store = await openStore();
    final stamp = await store.save(image: _bytes, caption: 'hi');

    expect(stamp.id, isNotEmpty);
    expect(stamp.caption, 'hi');
    expect(File(stamp.imagePath).existsSync(), isTrue);
    expect(File(stamp.imagePath).readAsBytesSync(), _bytes);
    await store.close();
  });

  test('blank captions are stored as null', () async {
    final store = await openStore();
    final stamp = await store.save(image: _bytes, caption: '   ');
    expect(stamp.caption, isNull);
    await store.close();
  });

  test('stamps survive a reopen', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes, caption: 'kept');
    await store.close();

    final reopened = await openStore();
    final loaded = await reopened.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, saved.id);
    expect(loaded.single.caption, 'kept');
    expect(loaded.single.date, saved.date);
    await reopened.close();
  });

  test('the image path resolves under the current documents directory',
      () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes);
    await store.close();

    // Simulates a restore: same files, different absolute parent path.
    final moved = await Directory.systemTemp.createTemp('postmark_moved');
    addTearDown(() async => moved.delete(recursive: true));
    await for (final entity in docs.list(recursive: true)) {
      if (entity is! File) continue;
      final target = File(p.join(moved.path, p.relative(entity.path, from: docs.path)));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }

    final movedStore = StampStore(StampPaths(moved));
    await movedStore.open();
    final loaded = await movedStore.loadAll();

    expect(loaded.single.id, saved.id);
    expect(loaded.single.imagePath, startsWith(moved.path));
    expect(File(loaded.single.imagePath).existsSync(), isTrue);
    await movedStore.close();
  });
}
