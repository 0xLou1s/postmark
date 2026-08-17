import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/data/stamp_repository.dart';
import 'package:postmark/data/stamp_store.dart';
import 'package:postmark/domain/stamp.dart';

final _bytes = Uint8List.fromList([1, 2, 3, 4]);

/// An in-memory store. These tests are about how a delete maps onto the
/// observable list, not about disk and DB behaviour, which is covered against a
/// real database in `test/data/stamp_store_test.dart`.
class _FakeStampStore implements StampStore {
  final List<Stamp> _stamps = [];
  var _nextId = 0;

  /// Ids that throw when deleted, standing in for an I/O failure.
  final Set<String> failOnDelete = {};

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> reconcile() async {}

  @override
  Future<List<Stamp>> loadAll() async => List.of(_stamps);

  @override
  Future<Stamp> save({required Uint8List image, String? caption}) async {
    final stamp = Stamp(
      id: '${_nextId++}',
      imagePath: '/fake/stamps/$_nextId.jpg',
      date: DateTime(2026, 8, 18),
      caption: caption,
    );
    _stamps.add(stamp);
    return stamp;
  }

  @override
  Future<void> delete(String id) async {
    if (failOnDelete.contains(id)) throw Exception('delete failed');
    _stamps.removeWhere((s) => s.id == id);
  }

  /// Mirrors SqliteStampStore: every id is attempted, the first error is
  /// rethrown at the end.
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
}

void main() {
  late _FakeStampStore store;
  late SqliteStampRepository repository;

  setUp(() async {
    store = _FakeStampStore();
    repository = SqliteStampRepository(store);
    await repository.initialize();
  });

  tearDown(() => repository.dispose());

  test('removing a stamp takes it out of the book', () async {
    final kept = await repository.add(image: _bytes, caption: 'kept');
    final doomed = await repository.add(image: _bytes, caption: 'doomed');

    await repository.remove({doomed.id});

    expect(repository.state, hasLength(1));
    expect(repository.state.single.id, kept.id);
  });

  test('removing several stamps takes all of them out', () async {
    final first = await repository.add(image: _bytes);
    final second = await repository.add(image: _bytes);
    final kept = await repository.add(image: _bytes);

    await repository.remove({first.id, second.id});

    expect(repository.state.single.id, kept.id);
  });

  test('a failed delete leaves the book unchanged', () async {
    final stamp = await repository.add(image: _bytes, caption: 'still here');
    store.failOnDelete.add(stamp.id);

    await expectLater(repository.remove({stamp.id}), throwsA(anything));

    // Showing it as gone would be a lie: the row and the file are both intact.
    expect(repository.state, hasLength(1));
    expect(repository.state.single.id, stamp.id);
  });

  test('a partly failed batch reloads rather than guessing', () async {
    final deleted = await repository.add(image: _bytes, caption: 'gone');
    final stuck = await repository.add(image: _bytes, caption: 'stuck');
    store.failOnDelete.add(stuck.id);

    await expectLater(
      repository.remove({deleted.id, stuck.id}),
      throwsA(anything),
    );

    // Filtering out both ids would drop a stamp that is still on disk.
    expect(repository.state, hasLength(1));
    expect(repository.state.single.id, stuck.id);
  });
}
