import 'dart:typed_data';

import 'package:postmark/data/stamp_store.dart';
import 'package:postmark/domain/stamp.dart';

/// A store that keeps stamps in memory, because `sqflite` cannot run under
/// `testWidgets` — its ffi factory hangs on the Flutter test binding.
/// Persistence itself is covered in `test/data/stamp_store_test.dart`.
class FakeStampStore implements StampStore {
  final List<Stamp> _stamps = [];

  /// Ids whose delete throws, exercising a screen's failure path.
  final Set<String> failOnDelete = {};

  void seed(Stamp stamp) => _stamps.add(stamp);

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> reconcile() async {}

  @override
  Future<List<Stamp>> loadAll() async => List.of(_stamps);

  @override
  Future<void> delete(String id) async {
    if (failOnDelete.contains(id)) throw Exception('disk error');
    _stamps.removeWhere((stamp) => stamp.id == id);
  }

  /// Mirrors [SqliteStampStore.deleteAll]: every id is attempted even after
  /// one fails, and the first failure is reported once all have been tried.
  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    Object? firstError;
    for (final id in ids) {
      try {
        await delete(id);
      } catch (error) {
        firstError ??= error;
      }
    }
    if (firstError != null) throw firstError;
  }

  @override
  Future<Stamp> save({required Uint8List image, String? caption}) async =>
      throw UnimplementedError();
}
