import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where stamp images live.
///
/// Paths are stored relative and resolved on read: the documents directory's
/// absolute path changes between installs and after a backup restore, so
/// absolute paths would break every image.
class StampPaths {
  StampPaths(this.documentsDir);

  /// Tests construct [StampPaths] directly with a temp directory instead.
  static Future<StampPaths> forApp() async =>
      StampPaths(await getApplicationDocumentsDirectory());

  final Directory documentsDir;

  static const _stampsDirName = 'stamps';

  /// The directory holding stamp JPEGs, created if absent.
  Future<Directory> ensureStampsDir() async {
    final dir = Directory(p.join(documentsDir.path, _stampsDirName));
    return dir.create(recursive: true);
  }

  /// Relative path stored in the DB, e.g. `stamps/<uuid>.jpg`.
  String relativeFor(String id) => p.join(_stampsDirName, '$id.jpg');

  /// Absolute path for a relative path read back out of the DB.
  String absoluteFor(String relativePath) =>
      p.join(documentsDir.path, relativePath);

  /// The inverse of [relativeFor]. Filename and id are the same value, which is
  /// what lets an orphaned file be adopted back under the id it already had.
  String idForFile(File file) => p.basenameWithoutExtension(file.path);
}
