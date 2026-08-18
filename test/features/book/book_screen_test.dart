import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:postmark/data/stamp_repository.dart';
import 'package:postmark/domain/stamp.dart';
import 'package:postmark/features/book/book_screen.dart';
import 'package:postmark/features/book/widgets/stamp_tile.dart';

import '../../support/fake_stamp_store.dart';

Stamp _stamp(String id, DateTime date) =>
    Stamp(id: id, imagePath: '/fake/stamps/$id.jpg', date: date);

/// The book plus a stand-in detail route, so a tap that navigates is
/// distinguishable from one that only toggles a tile.
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/book',
    routes: [
      GoRoute(
        path: '/book',
        builder: (_, _) => const BookScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => Scaffold(
              body: Center(child: Text('detail:${state.pathParameters['id']}')),
            ),
          ),
        ],
      ),
    ],
  );
}

late FakeStampStore _store;

Future<ProviderContainer> _pumpBook(WidgetTester tester) async {
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

Future<void> _longPressFirst(WidgetTester tester) async {
  await tester.longPress(find.byType(StampTile).first);
  await tester.pumpAndSettle();
}

void main() {
  final june = DateTime(2026, 6, 12);
  final july = DateTime(2026, 7, 3);

  setUp(() {
    _store = FakeStampStore()
      ..seed(_stamp('a', july))
      ..seed(_stamp('b', july))
      ..seed(_stamp('c', june));
  });

  testWidgets('tapping a stamp opens it while idle', (tester) async {
    await _pumpBook(tester);

    await tester.tap(find.byType(StampTile).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('detail:'), findsOneWidget);
  });

  testWidgets('long-pressing enters selection with that stamp', (tester) async {
    await _pumpBook(tester);

    await _longPressFirst(tester);

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.textContaining('detail:'), findsNothing);
  });

  testWidgets('tapping toggles instead of navigating while selecting', (
    tester,
  ) async {
    await _pumpBook(tester);
    await _longPressFirst(tester);

    await tester.tap(find.byType(StampTile).at(1));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.textContaining('detail:'), findsNothing);

    await tester.tap(find.byType(StampTile).at(1));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('deselecting the last stamp returns the book to idle', (
    tester,
  ) async {
    await _pumpBook(tester);
    await _longPressFirst(tester);

    await tester.tap(find.byType(StampTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Stamp Book'), findsOneWidget);
    expect(find.textContaining('selected'), findsNothing);
    expect(find.textContaining('detail:'), findsNothing);
  });

  testWidgets('the close action exits selection without leaving the book', (
    tester,
  ) async {
    await _pumpBook(tester);
    await _longPressFirst(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Stamp Book'), findsOneWidget);
    expect(find.byType(StampTile), findsNWidgets(3));
  });

  testWidgets('back exits selection rather than leaving the book', (
    tester,
  ) async {
    await _pumpBook(tester);
    await _longPressFirst(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Stamp Book'), findsOneWidget);
    expect(find.byType(StampTile), findsNWidgets(3));
  });

  testWidgets('confirming a delete removes the selected stamps', (
    tester,
  ) async {
    final container = await _pumpBook(tester);
    await _longPressFirst(tester);
    await tester.tap(find.byType(StampTile).at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      container.read(stampRepositoryProvider).map((s) => s.id),
      ['c'],
    );
    expect(find.byType(StampTile), findsOneWidget);
    expect(find.text('Stamp Book'), findsOneWidget);
  });

  testWidgets('cancelling keeps the stamps and keeps the selection', (
    tester,
  ) async {
    final container = await _pumpBook(tester);
    await _longPressFirst(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(stampRepositoryProvider), hasLength(3));
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('a failed delete reports it and keeps the selection', (
    tester,
  ) async {
    final container = await _pumpBook(tester);
    _store.failOnDelete.add('a');

    await _longPressFirst(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't delete that. Try again."), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(container.read(stampRepositoryProvider), hasLength(3));
  });

  testWidgets('a partly failed delete shows what the store actually deleted', (
    tester,
  ) async {
    final container = await _pumpBook(tester);
    _store.failOnDelete.add('a');

    // Both July stamps: 'b' deletes, 'a' does not.
    await _longPressFirst(tester);
    await tester.tap(find.byType(StampTile).at(1));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // The book shows the stamps that survived, not the ones that were asked
    // for: 'b' is gone even though the batch as a whole failed.
    expect(
      container.read(stampRepositoryProvider).map((s) => s.id),
      unorderedEquals(['a', 'c']),
    );
    expect(find.text("Couldn't delete that. Try again."), findsOneWidget);
    // The whole selection survives, so a retry needs no reselecting.
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('deleting a month\'s only stamp removes its header', (
    tester,
  ) async {
    await _pumpBook(tester);
    final juneLabel = StampDateFormat.monthYear(june);
    final julyLabel = StampDateFormat.monthYear(july);
    expect(find.text(juneLabel), findsOneWidget);

    // The June stamp is the last tile: months run newest first.
    await tester.longPress(find.byType(StampTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text(juneLabel), findsNothing);
    expect(find.text(julyLabel), findsOneWidget);
  });
}
