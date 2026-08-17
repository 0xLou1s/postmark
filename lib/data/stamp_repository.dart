import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/stamp.dart';
import 'stamp_paths.dart';
import 'stamp_store.dart';

/// Exposes the durable stamp store to the UI as observable state.
class SqliteStampRepository extends StateNotifier<List<Stamp>> {
  SqliteStampRepository(this._store) : super(const []);

  final StampStore _store;

  var _ready = false;

  /// Opens the store, repairs any disagreement between disk and database, and
  /// publishes the stamps. Safe to call more than once — a hot restart or a
  /// rebuilt provider re-enters it against a directory that is already
  /// populated, and [StampStore.reconcile] is idempotent.
  Future<void> initialize() async {
    await _store.open();
    await _store.reconcile();
    state = await _store.loadAll();
    _ready = true;
  }

  Future<Stamp> add({required Uint8List image, String? caption}) async {
    // Saving into a store that never opened would throw from deep inside
    // sqflite. Failing here instead gives PreviewScreen the same error it
    // already handles, so the user gets "couldn't save, try again" and keeps
    // the photo on screen rather than hitting an unhandled crash.
    if (!_ready) {
      throw StateError('The stamp book is unavailable; storage failed to open');
    }
    final stamp = await _store.save(image: image, caption: caption);
    state = [...state, stamp];
    return stamp;
  }

  Stamp? byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Overridden in `main()` once the documents directory has been resolved, and
/// in tests with a temp directory.
final stampStoreProvider = Provider<StampStore>(
  (ref) => throw UnimplementedError('stampStoreProvider must be overridden'),
);

/// The repository as a StateNotifier so widgets rebuild on change.
final stampRepositoryProvider =
    StateNotifierProvider<SqliteStampRepository, List<Stamp>>(
  (ref) => SqliteStampRepository(ref.watch(stampStoreProvider)),
);

/// Convenience: stamps grouped by month for the Stamp Book.
final stampGroupsProvider = Provider<List<MonthGroup>>((ref) {
  final stamps = ref.watch(stampRepositoryProvider);
  return groupByMonth(stamps);
});

/// Builds a store over the real app documents directory.
Future<StampStore> createAppStampStore() async =>
    SqliteStampStore(await StampPaths.forApp());
