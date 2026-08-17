import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:postmark/data/stamp_repository.dart';
import 'package:postmark/data/stamp_store.dart';
import 'package:postmark/domain/stamp.dart';
import 'package:postmark/features/book/stamp_detail_screen.dart';

/// A store that keeps stamps in memory, because `sqflite` cannot run under
/// `testWidgets` — its ffi factory hangs on the Flutter test binding.
/// Persistence itself is covered in `test/data/stamp_store_test.dart`.
class _FakeStampStore implements StampStore {
  final List<Stamp> _stamps = [];

  /// Ids whose delete throws, exercising the detail screen's failure path.
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

late _FakeStampStore _store;

/// The detail screen pushed over a stand-in book, so a pop back to the book is
/// observable.
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/book/a',
    routes: [
      GoRoute(
        path: '/book',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('book screen'))),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                StampDetailScreen(stampId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}

Future<ProviderContainer> _pumpDetail(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [stampStoreProvider.overrideWithValue(_store)],
  );
  addTearDown(container.dispose);
  await container.read(stampRepositoryProvider.notifier).initialize();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    _store = _FakeStampStore()
      ..seed(
        Stamp(
          id: 'a',
          imagePath: '/fake/stamps/a.jpg',
          date: DateTime(2026, 7, 3),
          caption: 'a quiet street',
        ),
      );
  });

  testWidgets('confirming a delete removes the stamp and returns to the book', (
    tester,
  ) async {
    final container = await _pumpDetail(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(container.read(stampRepositoryProvider), isEmpty);
    expect(find.text('book screen'), findsOneWidget);
    expect(find.text('a quiet street'), findsNothing);
  });

  testWidgets('cancelling keeps the stamp and stays on the detail screen', (
    tester,
  ) async {
    final container = await _pumpDetail(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(stampRepositoryProvider), hasLength(1));
    expect(find.text('a quiet street'), findsOneWidget);
  });

  testWidgets('a failed delete reports it and keeps the stamp on screen', (
    tester,
  ) async {
    final container = await _pumpDetail(tester);
    _store.failOnDelete.add('a');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't delete that. Try again."), findsOneWidget);
    expect(container.read(stampRepositoryProvider), hasLength(1));
    expect(find.text('a quiet street'), findsOneWidget);
    expect(find.text('book screen'), findsNothing);
  });
}
