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
  Future<SqliteStampStore> openStore() async {
    final store = SqliteStampStore(StampPaths(docs));
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

    final movedStore = SqliteStampStore(StampPaths(moved));
    await movedStore.open();
    final loaded = await movedStore.loadAll();

    expect(loaded.single.id, saved.id);
    expect(loaded.single.imagePath, startsWith(moved.path));
    expect(File(loaded.single.imagePath).existsSync(), isTrue);
    await movedStore.close();
  });

  test('an orphaned image is adopted back into the book', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes, caption: 'orphan');
    // Drop the row but keep the file — the crash state save() is designed for.
    await store.debugDeleteRow(saved.id);
    await store.close();

    final reopened = await openStore();
    await reopened.reconcile();
    final loaded = await reopened.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, saved.id, reason: 'id comes from the filename');
    expect(loaded.single.caption, isNull, reason: 'the caption was in the row');
    expect(File(loaded.single.imagePath).existsSync(), isTrue);
    await reopened.close();
  });

  test('a row whose file is gone is dropped', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes);
    await File(saved.imagePath).delete();
    await store.reconcile();

    expect(await store.loadAll(), isEmpty);
    await store.close();
  });

  test('a stale interrupted write is deleted, not adopted', () async {
    final store = await openStore();
    final stray = File(p.join(docs.path, 'stamps', 'half-written.jpg.tmp'));
    await stray.writeAsBytes(_bytes);
    // Backdate it past the grace period so it reads as a previous run's debris.
    await stray.setLastModified(
      DateTime.now().subtract(const Duration(hours: 1)),
    );

    await store.reconcile();

    expect(await store.loadAll(), isEmpty);
    expect(stray.existsSync(), isFalse);
    await store.close();
  });

  test('a temp file from an in-flight save is left alone', () async {
    final store = await openStore();
    final inFlight = File(p.join(docs.path, 'stamps', 'being-written.jpg.tmp'));
    await inFlight.writeAsBytes(_bytes);

    await store.reconcile();

    // Deleting this would destroy a capture that is still being written.
    expect(inFlight.existsSync(), isTrue);
    expect(await store.loadAll(), isEmpty);
    await store.close();
  });

  test('an unreadable image keeps its row', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes, caption: 'corrupt');
    // The file exists but holds no valid image. Reconciliation must not treat
    // a decode failure as a missing file — that would delete the user's only
    // record of the photo, and the failure may be transient.
    await File(saved.imagePath).writeAsString('not an image');

    await store.reconcile();
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.caption, 'corrupt');
    await store.close();
  });

  test('a file with a non-uuid name is adopted and renamed', () async {
    final store = await openStore();
    final stray = File(p.join(docs.path, 'stamps', 'from-a-backup.jpg'));
    await stray.writeAsBytes(_bytes);

    await store.reconcile();
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1));
    expect(p.basenameWithoutExtension(loaded.single.imagePath), loaded.single.id,
        reason: 'the file is renamed so filename and id stay the same value');
    expect(File(loaded.single.imagePath).existsSync(), isTrue);
    expect(stray.existsSync(), isFalse);
    await store.close();
  });

  test('reconcile is idempotent', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes, caption: 'kept');
    await store.debugDeleteRow(saved.id);

    await store.reconcile();
    final afterFirst = await store.loadAll();
    await store.reconcile();
    final afterSecond = await store.loadAll();

    expect(afterFirst, hasLength(1));
    expect(afterSecond, hasLength(1), reason: 'no duplicate row, no re-adoption');
    expect(afterSecond.single.id, afterFirst.single.id);
    await store.close();
  });
}
