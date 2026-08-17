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
  await container.read(stampRepositoryProvider.notifier).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PostmarkApp(),
    ),
  );
}
