import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/postmark_nav.dart';

/// Hosts the active branch (Stamp / Book) with a persistent pill nav floating
/// at the bottom. Each branch keeps its own navigation state.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: PostmarkNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
