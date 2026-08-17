import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/perforated_border.dart';
import '../machine_metrics.dart';
import 'machine_frame.dart';

/// The cut-out stamp ejecting up out of the slot over the bezel, with the
/// window left black. Anchored to the same spot as the live frame so it
/// reads as the same machine.
class EjectOverlay extends StatelessWidget {
  const EjectOverlay({
    super.key,
    required this.animation,
    required this.image,
  });

  final Animation<double> animation;
  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value.clamp(0.0, 1.0);
          return ColoredBox(
            color: Colors.black.withValues(
              alpha: AppColors.scrimMaxOpacity * t,
            ),
            child: Padding(
              padding: MachineMetrics.insets,
              child: Center(
                child: MachineEjectFrame(
                  progress: t,
                  stamp: StampFrame(
                    child: Image.memory(image, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
