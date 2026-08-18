import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:postmark/data/stamp_paths.dart';
import 'package:postmark/data/stamp_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Bytes only need to be distinguishable on disk; the store never decodes them.
final _bytes = Uint8List.fromList([1, 2, 3, 4]);

/// The real store with seams for the two failures that cannot be provoked from
/// outside: an insert that fails once the image is already on disk, and a file
/// that disappears between the directory listing and its adoption.
class _FaultyStampStore extends SqliteStampStore {
  _FaultyStampStore(super.paths);

  bool failNextInsert = false;
  Future<void> Function()? beforeAdopt;

  /// Ids whose delete throws, keyed to the exception it throws.
  final Map<String, Object> failDeleteFor = {};

  @override
  Future<void> delete(String id) async {
    final failure = failDeleteFor[id];
    if (failure != null) throw failure;
    return super.delete(id);
  }

  @override
  Future<void> insertStamp(Map<String, Object?> values) async {
    if (failNextInsert) {
      failNextInsert = false;
      throw Exception('insert failed');
    }
    return super.insertStamp(values);
  }

  @override
  Future<void> adoptFile(File file, String id) async {
    await beforeAdopt?.call();
    return super.adoptFile(file, id);
  }
}

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
  Future<_FaultyStampStore> openStore() async {
    final store = _FaultyStampStore(StampPaths(docs));
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

  test('opening twice is a no-op, as a hot restart does', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes, caption: 'kept');

    await store.open();

    expect((await store.loadAll()).single.id, saved.id);
    await store.close();
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

  test('one unadoptable file does not abort the whole sweep', () async {
    final store = await openStore();
    final healthy = await store.save(image: _bytes, caption: 'keep me');
    await store.debugDeleteRow(healthy.id);

    // A file that vanishes between the directory listing and the adopt call —
    // the same shape as any per-file I/O error during a sweep. It must not stop
    // the healthy orphan beside it from being recovered.
    final doomed = File(p.join(docs.path, 'stamps', 'aaaa-vanishing.jpg'));
    await doomed.writeAsBytes(_bytes);
    store.beforeAdopt = () async {
      if (doomed.existsSync()) await doomed.delete();
    };

    await store.reconcile();
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1), reason: 'the healthy orphan still came back');
    expect(loaded.single.id, healthy.id);
    await store.close();
  });

  test('a failed save leaves nothing behind to duplicate later', () async {
    final store = await openStore();

    // The row insert fails after the JPEG is already on disk. Without cleanup
    // that file would be adopted as its own captionless stamp on the next
    // launch, so the user's retry would put the same photo in the book twice.
    store.failNextInsert = true;
    await expectLater(
      store.save(image: _bytes, caption: 'first try'),
      throwsA(anything),
    );

    final retried = await store.save(image: _bytes, caption: 'second try');
    await store.reconcile();
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1), reason: 'no orphan left to adopt separately');
    expect(loaded.single.id, retried.id);
    expect(loaded.single.caption, 'second try');
    await store.close();
  });

  test('deleting a stamp removes both its file and its row', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes, caption: 'goodbye');

    await store.delete(saved.id);

    expect(await store.loadAll(), isEmpty);
    expect(File(saved.imagePath).existsSync(), isFalse);
    await store.close();
  });

  test('deleting a stamp whose file is already gone still drops the row',
      () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes);
    // The file half is already done — a crash mid-delete looks exactly like
    // this — so the row deletion must still complete rather than throw.
    await File(saved.imagePath).delete();

    await store.delete(saved.id);

    expect(await store.loadAll(), isEmpty);
    await store.close();
  });

  test('deleting an unknown id is a no-op', () async {
    final store = await openStore();
    final kept = await store.save(image: _bytes, caption: 'kept');

    // A stale UI can issue a second delete for a stamp that is already gone.
    await store.delete('not-a-real-id');

    expect((await store.loadAll()).single.id, kept.id);
    await store.close();
  });

  test('deleteAll removes every selected stamp', () async {
    final store = await openStore();
    final first = await store.save(image: _bytes, caption: 'one');
    final second = await store.save(image: _bytes, caption: 'two');
    final kept = await store.save(image: _bytes, caption: 'three');

    await store.deleteAll([first.id, second.id]);
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, kept.id);
    expect(File(first.imagePath).existsSync(), isFalse);
    expect(File(second.imagePath).existsSync(), isFalse);
    expect(File(kept.imagePath).existsSync(), isTrue);
    await store.close();
  });

  test('deleteAll reports the first failure but still deletes the rest',
      () async {
    final store = await openStore();
    final doomed = await store.save(image: _bytes, caption: 'one');
    final alsoDoomed = await store.save(image: _bytes, caption: 'two');
    final survivor = await store.save(image: _bytes, caption: 'three');

    final first = Exception('first failure');
    store.failDeleteFor[doomed.id] = first;
    store.failDeleteFor[alsoDoomed.id] = Exception('second failure');

    await expectLater(
      store.deleteAll([doomed.id, alsoDoomed.id, survivor.id]),
      // The first error wins: a later one must not overwrite what the caller
      // is told went wrong.
      throwsA(same(first)),
    );

    // The failures must not have stranded the ids queued behind them.
    final loaded = await store.loadAll();
    expect(loaded, hasLength(2));
    expect(loaded.map((stamp) => stamp.id), isNot(contains(survivor.id)));
    expect(File(survivor.imagePath).existsSync(), isFalse);
    await store.close();
  });

  test('deleteAll rethrows the failure with its original stack trace',
      () async {
    final store = await openStore();
    final doomed = await store.save(image: _bytes);
    store.failDeleteFor[doomed.id] = Exception('boom');

    StackTrace? caught;
    try {
      await store.deleteAll([doomed.id]);
    } catch (_, stack) {
      caught = stack;
    }

    // Not a stack rooted at deleteAll's rethrow: the frame that actually threw
    // has to survive, or the report points at the accumulator instead of the
    // failure.
    expect(caught.toString(), contains('_FaultyStampStore.delete'));
    await store.close();
  });

  test('a deleted stamp does not come back after a crash mid-delete', () async {
    final store = await openStore();
    final saved = await store.save(image: _bytes, caption: 'goodbye');

    // The crash state the delete ordering is designed to make the only
    // reachable one: the file is gone, the row survives. The reverse order
    // would leave an orphaned file that reconcile() adopts back into the book.
    await File(saved.imagePath).delete();
    await store.close();

    final reopened = await openStore();
    await reopened.reconcile();

    expect(await reopened.loadAll(), isEmpty);
    await reopened.close();
  });
}
