import 'package:go_router/go_router.dart';

import '../features/machine/machine_screen.dart';
import '../features/book/book_screen.dart';
import '../features/book/stamp_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const MachineScreen()),
    GoRoute(path: '/book', builder: (_, _) => const BookScreen()),
    GoRoute(
      path: '/book/:id',
      builder: (_, state) =>
          StampDetailScreen(stampId: state.pathParameters['id']!),
    ),
  ],
);
