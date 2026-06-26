import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/perforated_border.dart';
import '../../data/in_memory_stamp_repository.dart';

class StampDetailScreen extends ConsumerWidget {
  const StampDetailScreen({super.key, required this.stampId});
  final String stampId;

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp = ref.read(stampRepositoryProvider.notifier).byId(stampId);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                          aspectRatio: 3 / 4,
                          child: StampFrame(
                            child:
                                Image.memory(stamp.image, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (stamp.caption != null)
                      Text(stamp.caption!,
                          style: const TextStyle(
                              fontSize: 20, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text(_formatDate(stamp.date),
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
    );
  }
}
