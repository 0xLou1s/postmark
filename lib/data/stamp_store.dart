import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/stamp.dart';
import 'stamp_database.dart';
import 'stamp_paths.dart';

/// Exists so widget tests can avoid SQLite — `sqflite` hangs under the Flutter
/// test binding. Not a seam for testing persistence: that is covered against a
/// real database in `test/data/stamp_store_test.dart`.
abstract class StampStore {
  Future<void> open();
  Future<void> close();
  Future<Stamp> save({required Uint8List image, String? caption});
  Future<List<Stamp>> loadAll();
  Future<void> reconcile();
}

/// Older than this, a `.tmp` file is a previous run's debris rather than a
/// capture still being written.
const _staleTempFileAge = Duration(minutes: 1);

/// JPEG bytes on disk, metadata in SQLite.
///
/// Image bytes matter more than metadata: writes are ordered so the only
/// reachable failure is the recoverable one.
class SqliteStampStore implements StampStore {
  SqliteStampStore(this._paths);

  final StampPaths _paths;
  static const _uuid = Uuid();

  Database? _database;
  Directory? _stampsDir;

  /// Fails here rather than deep inside sqflite, so callers get the error they
  /// already handle for a failed write.
  Database get _db => _requireOpen();

  Database _requireOpen() {
    final db = _database;
    if (db == null) {
      throw StateError('The stamp book is unavailable; storage failed to open');
    }
    return db;
  }

  /// Idempotent, so a hot restart or a rebuilt provider can re-enter it.
  @override
  Future<void> open() async {
    if (_database != null) return;
    _stampsDir = await _paths.ensureStampsDir();
    _database = await StampDatabase.open(
      p.join(_paths.documentsDir.path, StampDatabase.fileName),
    );
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _stampsDir = null;
  }

  /// The file is written before the row: crashing between the two leaves an
  /// image [reconcile] adopts back, where the reverse order would lose the photo.
  @override
  Future<Stamp> save({required Uint8List image, String? caption}) async {
    // Before the write, so an unusable store leaves no stray image on disk.
    _requireOpen();

    final id = _uuid.v4();
    final relativePath = _paths.relativeFor(id);
    final absolutePath = _paths.absoluteFor(relativePath);
    // Millisecond precision, so the returned stamp matches what a reload gives.
    final date = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );

    await _writeImage(absolutePath, image);

    final trimmed = caption?.trim();
    final storedCaption =
        (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;

    try {
      await _insertStamp(
        id: id,
        relativePath: relativePath,
        date: date,
        caption: storedCaption,
      );
    } catch (_) {
      // Without this the file is adopted as its own stamp later, so a retry puts
      // the photo in the book twice. Safe only here: the caller still holds the
      // bytes. Reconciliation must never delete, where disk is the last copy.
      try {
        await File(absolutePath).delete();
      } catch (_) {
        // Leave it for reconciliation: a duplicate beats a lost photo.
      }
      rethrow;
    }

    return Stamp(
      id: id,
      imagePath: absolutePath,
      date: date,
      caption: storedCaption,
    );
  }

  /// The transaction is the boundary future multi-row writes (tags, thumbnails,
  /// a search index) land inside. Don't simplify it to a bare insert.
  ///
  /// Overridden in tests to fail after the image is on disk.
  @protected
  @visibleForOverriding
  Future<void> insertStamp(Map<String, Object?> values) =>
      _db.transaction((txn) => txn.insert(StampDatabase.table, values));

  Future<void> _insertStamp({
    required String id,
    required String relativePath,
    required DateTime date,
    required String? caption,
  }) =>
      insertStamp({
        StampDatabase.columnId: id,
        StampDatabase.columnImagePath: relativePath,
        StampDatabase.columnDate: date.millisecondsSinceEpoch,
        StampDatabase.columnCaption: caption,
      });

  /// Renaming is atomic within a filesystem, so the `.jpg` is never half
  /// written. The temp file must stay in the destination's directory — the
  /// system temp dir would cross filesystems and degrade this into a copy.
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
  /// Decided on file existence alone — never a decode, since one bad read may be
  /// transient and must not delete the user's only record of a photo.
  ///
  /// Idempotent: filename and id are the same value, so an adopted file already
  /// has a row on the next pass.
  @override
  Future<void> reconcile() async {
    final knownIds = await _dropRowsWithNoImage();
    await for (final entity in _stampsDir!.list()) {
      if (entity is! File) continue;
      await _reconcileFile(entity, knownIds);
    }
  }

  /// Deletes rows whose image is gone, returning the ids that still have one.
  Future<Set<String>> _dropRowsWithNoImage() async {
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
    return knownIds;
  }

  Future<void> _reconcileFile(File file, Set<String> knownIds) async {
    final name = p.basename(file.path);

    // Only debris from an earlier run: an in-flight save owns its temp file, and
    // deleting it mid-write would destroy a live capture.
    if (name.endsWith('.tmp')) {
      final age = DateTime.now().difference(await file.lastModified());
      if (age > _staleTempFileAge) await file.delete();
      return;
    }
    if (p.extension(name) != '.jpg') return;

    final id = _paths.idForFile(file);
    if (knownIds.contains(id)) return;

    // This runs at startup, so one bad file must not abort the sweep and cost
    // the user the rest of the book. It stays on disk for a later pass.
    try {
      await adoptFile(file, id);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'postmark',
        context: ErrorDescription('adopting $name'),
      ));
    }
  }

  /// Re-creates a row for an image that has none. The date is the file's mtime,
  /// which restores and copies rewrite — an approximate date beats no photo.
  ///
  /// Overridden in tests to simulate a file vanishing mid-sweep.
  @protected
  @visibleForOverriding
  Future<void> adoptFile(File file, String id) async {
    var adoptedFile = file;
    var adoptedId = id;

    // A restore or manual copy can leave a non-uuid name. Renaming keeps
    // filename and id equal, so the next sweep sees it as settled.
    if (!Uuid.isValidUUID(fromString: id)) {
      adoptedId = _uuid.v4();
      adoptedFile =
          await file.rename(_paths.absoluteFor(_paths.relativeFor(adoptedId)));
    }

    final modified = await adoptedFile.lastModified();

    // OR REPLACE so an interrupted sweep can't collide on the primary key next
    // startup.
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

  /// Drops a row but keeps its image — the crash state [save] is ordered to make
  /// the only reachable one. Tests only.
  @visibleForTesting
  Future<void> debugDeleteRow(String id) => _deleteRow(id);

  Future<void> _deleteRow(String id) => _db.delete(
        StampDatabase.table,
        where: '${StampDatabase.columnId} = ?',
        whereArgs: [id],
      );
}
