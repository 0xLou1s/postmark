import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:postmark/data/in_memory_stamp_repository.dart';
import 'package:postmark/features/preview/preview_screen.dart';

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

Future<void> _pumpApp(WidgetTester tester, Uint8List image) async {
  await tester.pumpWidget(
    ProviderScope(
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
    final container = ProviderContainer();
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
