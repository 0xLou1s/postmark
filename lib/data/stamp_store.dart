import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/stamp.dart';
import 'stamp_database.dart';
import 'stamp_paths.dart';

/// Where stamps are kept.
///
/// This exists for one narrow reason: `sqflite` cannot run under `testWidgets`
/// — the ffi factory hangs on the Flutter test binding — so widget tests that
/// only care about navigation need a seam that avoids SQLite entirely.
///
/// It is deliberately NOT a seam for testing persistence. The durability rules
/// live in [SqliteStampStore] and are covered against a real database in
/// `test/data/stamp_store_test.dart`; a fake would have none of that behaviour
/// and testing against one would assert on code the app never runs.
abstract class StampStore {
  Future<void> open();
  Future<void> close();
  Future<Stamp> save({required Uint8List image, String? caption});
  Future<List<Stamp>> loadAll();
  Future<void> reconcile();
}

/// Durable storage for stamps: JPEG bytes on disk, metadata in SQLite.
///
/// The invariant behind every method here is that image bytes matter more than
/// metadata. A photo the user chose to keep is the one thing the app must not
/// lose, so writes are ordered to make the recoverable failure the only
/// reachable one.
class SqliteStampStore implements StampStore {
  SqliteStampStore(this._paths);

  final StampPaths _paths;
  static const _uuid = Uuid();

  late final Database _db;
  late final Directory _stampsDir;

  @override
  Future<void> open() async {
    _stampsDir = await _paths.ensureStampsDir();
    _db = await StampDatabase.open(
      p.join(_paths.documentsDir.path, StampDatabase.fileName),
    );
  }

  @override
  Future<void> close() => _db.close();

  /// Persists [image] and returns the resulting stamp.
  ///
  /// The file is written before the row is inserted. Crashing between the two
  /// leaves an image with no row, which startup reconciliation adopts back;
  /// the reverse order would leave a row pointing at nothing, losing the photo.
  @override
  Future<Stamp> save({required Uint8List image, String? caption}) async {
    final id = _uuid.v4();
    final relativePath = _paths.relativeFor(id);
    final absolutePath = _paths.absoluteFor(relativePath);
    // Truncated to millisecond precision so the returned stamp matches what
    // a reload produces — SQLite stores millisecondsSinceEpoch, not micros.
    final date =
        DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);

    await _writeImage(absolutePath, image);

    final trimmed = caption?.trim();
    final storedCaption =
        (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;

    // Wrapped in a transaction even though a single insert is already atomic:
    // this is the boundary future multi-row writes (tags, caption history,
    // thumbnails, a search index) will land inside, so it belongs here now
    // rather than being retrofitted later. Don't simplify this to a bare
    // insert.
    await _db.transaction((txn) async {
      await txn.insert(StampDatabase.table, {
        StampDatabase.columnId: id,
        StampDatabase.columnImagePath: relativePath,
        StampDatabase.columnDate: date.millisecondsSinceEpoch,
        StampDatabase.columnCaption: storedCaption,
      });
    });

    return Stamp(
      id: id,
      imagePath: absolutePath,
      date: date,
      caption: storedCaption,
    );
  }

  /// Writes bytes through a temp file, then renames into place.
  ///
  /// The rename is atomic within a filesystem, so the final `.jpg` is either
  /// absent or complete — a half-written JPEG is never observable. The temp
  /// file must sit in the same directory as its destination; putting it in the
  /// system temp directory would cross filesystems and silently degrade the
  /// rename into a copy.
  Future<void> _writeImage(String absolutePath, Uint8List bytes) async {
    final temp = File('$absolutePath.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(absolutePath);
  }

  /// Every stamp, newest first.
  @override
  Future<List<Stamp>> loadAll() async {
    final rows = await _db.query(
      StampDatabase.table,
      orderBy: '${StampDatabase.columnDate} DESC',
    );
    return rows.map(_stampFromRow).toList();
  }

  Stamp _stampFromRow(Map<String, Object?> row) => Stamp(
        id: row[StampDatabase.columnId]! as String,
        imagePath:
            _paths.absoluteFor(row[StampDatabase.columnImagePath]! as String),
        date: DateTime.fromMillisecondsSinceEpoch(
          row[StampDatabase.columnDate]! as int,
        ),
        caption: row[StampDatabase.columnCaption] as String?,
      );

  /// Repairs disagreements between the `stamps/` directory and the table.
  ///
  /// Decisions are made purely on file *existence*; no image is ever opened or
  /// decoded. A file that exists but cannot be read keeps its row, because one
  /// bad read — possibly transient — must not delete the user's only record of
  /// a photo.
  ///
  /// Idempotent: filename and id are the same value, so a file adopted on one
  /// pass already has a row on the next and is no longer an orphan.
  @override
  Future<void> reconcile() async {
    final rows = await _db.query(
      StampDatabase.table,
      columns: [StampDatabase.columnId, StampDatabase.columnImagePath],
    );

    final knownIds = <String>{};
    for (final row in rows) {
      final id = row[StampDatabase.columnId]! as String;
      final relativePath = row[StampDatabase.columnImagePath]! as String;
      if (File(_paths.absoluteFor(relativePath)).existsSync()) {
        knownIds.add(id);
      } else {
        await _deleteRow(id);
      }
    }

    await for (final entity in _stampsDir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);

      // Interrupted writes may hold a partial JPEG; they are not photos yet.
      // Only sweep ones left by an earlier run: a save happening right now owns
      // its temp file, and deleting it mid-write would destroy a live capture.
      if (name.endsWith('.tmp')) {
        final age = DateTime.now().difference(await entity.lastModified());
        if (age > const Duration(minutes: 1)) await entity.delete();
        continue;
      }
      if (p.extension(name) != '.jpg') continue;

      final id = _paths.idForFile(entity);
      if (knownIds.contains(id)) continue;

      await _adopt(entity, id);
    }
  }

  /// Re-creates a row for an image that has none.
  ///
  /// The date comes from the file's modification time, which is best-effort
  /// rather than the original capture time — backup restores and manual copies
  /// both rewrite it. An approximate date beats dropping the photo.
  Future<void> _adopt(File file, String id) async {
    var adoptedFile = file;
    var adoptedId = id;

    // Nothing the app writes is named this way, but a restore or a manual copy
    // can produce one. Renaming keeps filename and id the same value, so the
    // next sweep sees it as settled.
    if (!Uuid.isValidUUID(fromString: id)) {
      adoptedId = _uuid.v4();
      adoptedFile =
          await file.rename(_paths.absoluteFor(_paths.relativeFor(adoptedId)));
    }

    final modified = await adoptedFile.lastModified();

    // OR REPLACE so a sweep interrupted partway cannot make the next startup
    // throw on a primary-key collision.
    await _db.insert(
      StampDatabase.table,
      {
        StampDatabase.columnId: adoptedId,
        StampDatabase.columnImagePath: _paths.relativeFor(adoptedId),
        StampDatabase.columnDate: modified.millisecondsSinceEpoch,
        StampDatabase.columnCaption: null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _deleteRow(String id) => _db.delete(
        StampDatabase.table,
        where: '${StampDatabase.columnId} = ?',
        whereArgs: [id],
      );

  /// Drops a row while leaving its image in place, reproducing the crash state
  /// that [save] is ordered to make the only reachable one. Tests only.
  @visibleForTesting
  Future<void> debugDeleteRow(String id) => _deleteRow(id);
}
