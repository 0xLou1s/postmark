import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/stamp_repository.dart';
import 'widgets/month_section.dart';

class BookScreen extends ConsumerWidget {
  const BookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(stampGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stamp Book'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: groups.isEmpty
          ? const Center(
              child: Text('No stamps yet.\nPrint your first one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final g in groups)
                  MonthSection(
                    group: g,
                    selectedIds: const {},
                    onTapStamp: (stamp) => context.push('/book/${stamp.id}'),
                    onLongPressStamp: (_) {},
                  ),
              ],
            ),
    );
  }
}
