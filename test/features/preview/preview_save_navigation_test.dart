import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:postmark/data/stamp_repository.dart';
import 'package:postmark/data/stamp_store.dart';
import 'package:postmark/domain/stamp.dart';
import 'package:postmark/features/preview/preview_screen.dart';

/// A store that keeps stamps in memory.
///
/// These tests are about navigation — that saving leaves the preview off the
/// Stamp branch's stack — not about persistence, which is covered against a
/// real database in `test/data/stamp_store_test.dart`. `sqflite` cannot run
/// under `testWidgets` (its ffi factory hangs on the Flutter test binding), so
/// the real store is not an option here regardless.
class _FakeStampStore implements StampStore {
  final List<Stamp> _stamps = [];
  var _nextId = 0;

  /// Set to make [save] throw, exercising the failure path.
  bool failOnSave = false;

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
    if (failOnSave) throw Exception('disk full');
    final trimmed = caption?.trim();
    final stamp = Stamp(
      id: '${_nextId++}',
      imagePath: '/fake/stamps/${_stamps.length}.jpg',
      date: DateTime(2026, 8, 17),
      caption: (trimmed != null && trimmed.isNotEmpty) ? trimmed : null,
    );
    _stamps.add(stamp);
    return stamp;
  }
}

/// A two-branch shell mirroring the real router: a Stamp branch that pushes
/// PreviewScreen on top of itself, and a Book branch. The real MachineScreen
/// needs a camera, so this stands in for it — the stack behaviour under test
/// belongs to the shell and PreviewScreen, not to the camera.
GoRouter _buildRouter(Uint8List image) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: Row(
            children: [
              TextButton(
                onPressed: () => shell.goBranch(0),
                child: const Text('go-stamp'),
              ),
              TextButton(
                onPressed: () => shell.goBranch(1),
                child: const Text('go-book'),
              ),
            ],
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('camera'),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PreviewScreen(image: image),
                            ),
                          ),
                          child: const Text('open-preview'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/book',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('book'))),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

late _FakeStampStore _store;

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [stampStoreProvider.overrideWithValue(_store)],
  );
  await container.read(stampRepositoryProvider.notifier).initialize();
  return container;
}

Future<void> _pumpApp(WidgetTester tester, Uint8List image) async {
  final container = await _container();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _buildRouter(image)),
    ),
  );
  await tester.pumpAndSettle();
}

/// A valid 1x1 red PNG. PreviewScreen renders the bytes, so a decodable image
/// is required — arbitrary bytes make the image codec throw.
final _pngPixel = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, //
  0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0,
  144, 119, 83, 222, //
  0, 0, 0, 12, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 0, 0, 3, 1, 1, 0,
  201, 254, 146, 239, //
  0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  final image = _pngPixel;

  setUp(() => _store = _FakeStampStore());

  testWidgets('saving leaves the Stamp branch showing the camera', (
    tester,
  ) async {
    await _pumpApp(tester, image);

    await tester.tap(find.text('open-preview'));
    await tester.pumpAndSettle();
    expect(find.text('Save to Book'), findsOneWidget);

    await tester.tap(find.text('Save to Book'));
    await tester.pumpAndSettle();
    expect(find.text('book'), findsOneWidget);

    // Returning to Stamp must land on the camera, not the preview it was
    // pushed over.
    await tester.tap(find.text('go-stamp'));
    await tester.pumpAndSettle();
    expect(find.text('camera'), findsOneWidget);
    expect(find.text('Save to Book'), findsNothing);
  });

  testWidgets('saving stores the stamp once', (tester) async {
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: _buildRouter(image)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to Book'));
    await tester.pumpAndSettle();

    expect(container.read(stampRepositoryProvider), hasLength(1));
  });

  testWidgets('a failed save keeps the preview so the photo is not lost', (
    tester,
  ) async {
    _store.failOnSave = true;
    await _pumpApp(tester, image);

    await tester.tap(find.text('open-preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to Book'));
    await tester.pumpAndSettle();

    // Still on the preview, with the bytes in hand, so the user can retry.
    expect(find.text('Save to Book'), findsOneWidget);
    expect(find.text('book'), findsNothing);
    expect(find.text("Couldn't save that stamp. Try again."), findsOneWidget);
  });

  testWidgets('retake also leaves the camera on top', (tester) async {
    await _pumpApp(tester, image);

    await tester.tap(find.text('open-preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();

    expect(find.text('camera'), findsOneWidget);
    expect(find.text('Save to Book'), findsNothing);
  });
}
