import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/perforated_border.dart';
import '../../../domain/stamp.dart';
import 'stamp_image.dart';

class StampTile extends StatelessWidget {
  const StampTile({
    super.key,
    required this.stamp,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
  });

  final Stamp stamp;

  /// What a tap means depends on whether the book is selecting, which the tile
  /// does not know, so the caller decides.
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  static const _decodeWidth = 400;
  static const _notchRadius = 5.0;

  static const _dimColor = Color(0x99000000);
  static const _checkSize = 22.0;
  static const _checkInset = 6.0;
  static const _checkIconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AspectRatio(
        aspectRatio: kStampAspectRatio,
        child: StampFrame(
          notchRadius: _notchRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              StampImage(
                imagePath: stamp.imagePath,
                decodeWidth: _decodeWidth,
              ),
              if (selected) ...[
                const ColoredBox(color: _dimColor),
                Positioned(
                  top: _checkInset,
                  right: _checkInset,
                  child: Container(
                    width: _checkSize,
                    height: _checkSize,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: _checkIconSize,
                      color: AppColors.paper,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
