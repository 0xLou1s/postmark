import 'package:sqflite/sqflite.dart';

/// Opens the stamp database and owns its schema.
class StampDatabase {
  static const fileName = 'postmark.db';
  static const table = 'stamps';

  static const columnId = 'id';
  static const columnImagePath = 'image_path';
  static const columnDate = 'date';
  static const columnCaption = 'caption';

  /// Opens (creating if needed) the database at [path].
  static Future<Database> open(String path) => openDatabase(
        path,
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE $table (
            $columnId TEXT PRIMARY KEY,
            $columnImagePath TEXT NOT NULL,
            $columnDate INTEGER NOT NULL,
            $columnCaption TEXT
          )
        '''),
      );
}
