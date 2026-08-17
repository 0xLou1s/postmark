import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/stamp_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved before the app starts because the documents directory is async.
  final store = await createAppStampStore();
  final container = ProviderContainer(
    overrides: [stampStoreProvider.overrideWithValue(store)],
  );

  // Startup must reach runApp even with storage unavailable: a locked or corrupt
  // database would otherwise strand the user on a dead launch screen. The book
  // comes up empty, but nothing on disk is touched, so a later launch recovers.
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
