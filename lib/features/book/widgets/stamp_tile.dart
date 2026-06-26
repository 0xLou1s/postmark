import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/perforated_border.dart';
import '../../../domain/stamp.dart';

class StampTile extends StatelessWidget {
  const StampTile({super.key, required this.stamp});
  final Stamp stamp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book/${stamp.id}'),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: StampFrame(
          notchRadius: 5,
          paperInset: 6,
          child: Image.memory(stamp.image, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
