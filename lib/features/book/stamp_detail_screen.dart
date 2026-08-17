import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/perforated_border.dart';
import '../../data/stamp_repository.dart';
import '../../domain/stamp.dart';
import 'widgets/delete_stamps_dialog.dart';
import 'widgets/stamp_image.dart';

class StampDetailScreen extends ConsumerWidget {
  const StampDetailScreen({super.key, required this.stampId});
  final String stampId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirmDeleteStamps(context, 1)) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(stampRepositoryProvider.notifier).remove({stampId});
      navigator.pop();
    } catch (_) {
      // Stays on the stamp, which is still in the book, so a retry is one tap.
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete that. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp = ref.watch(stampByIdProvider(stampId));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (stamp != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: stamp == null
          ? const Center(child: Text('Stamp not found.'))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: kStampAspectRatio,
                          child: StampFrame(
                            child: StampImage(imagePath: stamp.imagePath),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (stamp.caption != null)
                      Text(
                        stamp.caption!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      StampDateFormat.dayInFull(stamp.date),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
