import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/machine/machine_screen.dart';
import '../features/book/book_screen.dart';
import '../features/book/stamp_detail_screen.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Stamp (the camera/machine)
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const MachineScreen()),
          ],
        ),
        // Book (the stamp collection)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/book',
              builder: (_, _) => const BookScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) =>
                      StampDetailScreen(stampId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
