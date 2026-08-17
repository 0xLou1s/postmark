import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/perforated_border.dart';
import '../../data/stamp_repository.dart';
import '../../domain/stamp.dart';

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
                          aspectRatio: kStampAspectRatio,
                          child: StampFrame(
                            child: Image.file(
                              File(stamp.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFE8E4DC),
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: Colors.black26),
                                ),
                              ),
                            ),
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
