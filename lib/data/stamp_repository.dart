import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/stamp.dart';
import 'stamp_paths.dart';
import 'stamp_store.dart';

/// The stamp store as observable state for the UI.
class SqliteStampRepository extends StateNotifier<List<Stamp>> {
  SqliteStampRepository(this._store) : super(const []);

  final StampStore _store;

  /// Idempotent, so a hot restart or a rebuilt provider can re-enter it.
  Future<void> initialize() async {
    await _store.open();
    await _store.reconcile();
    state = await _store.loadAll();
  }

  Future<Stamp> add({required Uint8List image, String? caption}) async {
    final stamp = await _store.save(image: image, caption: caption);
    state = [...state, stamp];
    return stamp;
  }

  /// Removes stamps from the book. One id or many — a single delete is a set
  /// of one.
  ///
  /// State is updated only once the store call succeeds, so a failure leaves
  /// the book showing exactly what is still on disk.
  Future<void> remove(Iterable<String> ids) async {
    final gone = ids.toSet();
    try {
      await _store.deleteAll(gone);
    } catch (_) {
      // A batch can fail partway, so filtering by [gone] here would drop
      // stamps that were never deleted. Ask the store what actually survived.
      state = await _store.loadAll();
      rethrow;
    }
    state = [
      for (final stamp in state)
        if (!gone.contains(stamp.id)) stamp,
    ];
  }
}

/// Overridden in `main()` once the documents directory is resolved, and in tests
/// with a temp directory.
final stampStoreProvider = Provider<StampStore>(
  (ref) => throw UnimplementedError('stampStoreProvider must be overridden'),
);

final stampRepositoryProvider =
    StateNotifierProvider<SqliteStampRepository, List<Stamp>>(
  (ref) => SqliteStampRepository(ref.watch(stampStoreProvider)),
);

/// Stamps grouped by month for the Stamp Book.
final stampGroupsProvider = Provider<List<MonthGroup>>((ref) {
  return groupByMonth(ref.watch(stampRepositoryProvider));
});

/// A single stamp, watched so the detail screen follows later edits.
final stampByIdProvider = Provider.family<Stamp?, String>((ref, id) {
  for (final stamp in ref.watch(stampRepositoryProvider)) {
    if (stamp.id == id) return stamp;
  }
  return null;
});

Future<StampStore> createAppStampStore() async =>
    SqliteStampStore(await StampPaths.forApp());
