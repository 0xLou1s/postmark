import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/stamp.dart';
import 'stamp_database.dart';
import 'stamp_paths.dart';

/// Durable storage for stamps: JPEG bytes on disk, metadata in SQLite.
///
/// The invariant behind every method here is that image bytes matter more than
/// metadata. A photo the user chose to keep is the one thing the app must not
/// lose, so writes are ordered to make the recoverable failure the only
/// reachable one.
class StampStore {
  StampStore(this._paths);

  final StampPaths _paths;
  static const _uuid = Uuid();

  late final Database _db;

  Future<void> open() async {
    await _paths.ensureStampsDir();
    _db = await StampDatabase.open(
      p.join(_paths.documentsDir.path, StampDatabase.fileName),
    );
  }

  Future<void> close() => _db.close();

  /// Persists [image] and returns the resulting stamp.
  ///
  /// The file is written before the row is inserted. Crashing between the two
  /// leaves an image with no row, which startup reconciliation adopts back;
  /// the reverse order would leave a row pointing at nothing, losing the photo.
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
}
