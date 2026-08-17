import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/perforated_border.dart';
import '../../../domain/stamp.dart';

class StampTile extends StatelessWidget {
  const StampTile({super.key, required this.stamp});
  final Stamp stamp;

  /// Tiles are small; decoding a full camera JPEG at native resolution would
  /// hold a bitmap far larger than the grid needs.
  static const _decodeWidth = 400;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book/${stamp.id}'),
      child: AspectRatio(
        aspectRatio: kStampAspectRatio,
        child: StampFrame(
          notchRadius: 5,
          child: Image.file(
            File(stamp.imagePath),
            fit: BoxFit.cover,
            cacheWidth: _decodeWidth,
            // An unreadable file must not take down the whole book; the row and
            // the bytes both stay put.
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFE8E4DC),
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.black26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
