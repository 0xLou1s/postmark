import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/stamp_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The store needs the documents directory, which is async, so it is resolved
  // before the app starts and injected through the provider override.
  final store = await createAppStampStore();
  final container = ProviderContainer(
    overrides: [stampStoreProvider.overrideWithValue(store)],
  );

  // Startup must reach runApp even if storage is unavailable — a locked or
  // corrupt database would otherwise leave the user staring at a dead launch
  // screen with no way back to the camera. The book comes up empty in that
  // case, but nothing on disk has been touched, so a later launch that can
  // open the store still finds every stamp.
  try {
    await container.read(stampRepositoryProvider.notifier).initialize();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'postmark',
      context: ErrorDescription('opening the stamp book'),
    ));
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PostmarkApp(),
    ),
  );
}
