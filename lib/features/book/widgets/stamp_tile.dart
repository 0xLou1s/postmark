import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/perforated_border.dart';
import '../../../domain/stamp.dart';
import 'stamp_image.dart';

class StampTile extends StatelessWidget {
  const StampTile({super.key, required this.stamp});
  final Stamp stamp;

  static const _decodeWidth = 400;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book/${stamp.id}'),
      child: AspectRatio(
        aspectRatio: kStampAspectRatio,
        child: StampFrame(
          notchRadius: 5,
          child: StampImage(
            imagePath: stamp.imagePath,
            decodeWidth: _decodeWidth,
          ),
        ),
      ),
    );
  }
}
