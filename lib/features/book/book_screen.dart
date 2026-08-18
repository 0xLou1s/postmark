import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/stamp_repository.dart';
import 'stamp_selection.dart';
import 'widgets/delete_stamps_dialog.dart';
import 'widgets/month_section.dart';

class BookScreen extends ConsumerWidget {
  const BookScreen({super.key});

  Future<void> _deleteSelected(
    BuildContext context,
    WidgetRef ref,
    Set<String> selected,
  ) async {
    if (!await confirmDeleteStamps(context, selected.length)) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(stampRepositoryProvider.notifier).remove(selected);
      ref.read(stampSelectionProvider.notifier).clear();
    } catch (_) {
      // The selection is left alone so the user can retry without picking the
      // same stamps again.
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete that. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(stampGroupsProvider);
    final selected = ref.watch(stampSelectionProvider);
    final selection = ref.read(stampSelectionProvider.notifier);
    final isSelecting = selected.isNotEmpty;

    return PopScope(
      canPop: !isSelecting,
      // Back leaves the selection before it leaves the book; the callback always
      // clears, so a second back pops as usual. This blocks every pop while
      // selecting, not only the system gesture, which is only safe while /book
      // is a root route with nothing beneath it to go back to.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selection.clear();
      },
      child: Scaffold(
        appBar: isSelecting
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: selection.clear,
                ),
                title: Text('${selected.length} selected'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteSelected(context, ref, selected),
                  ),
                ],
                backgroundColor: Colors.transparent,
                elevation: 0,
              )
            : AppBar(
                title: const Text('Stamp Book'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
        body: groups.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: 0.4,
                      child: Image.asset(
                        'assets/postmark/logo.png',
                        width: 96,
                        height: 96,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('No stamps yet.\nPrint your first one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final g in groups)
                    MonthSection(
                      group: g,
                      selectedIds: selected,
                      onTapStamp: (stamp) => isSelecting
                          ? selection.toggle(stamp.id)
                          : context.push('/book/${stamp.id}'),
                      onLongPressStamp: (stamp) => selection.enter(stamp.id),
                    ),
                ],
              ),
      ),
    );
  }
}
