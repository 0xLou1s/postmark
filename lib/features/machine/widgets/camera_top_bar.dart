import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../machine_metrics.dart';
import 'camera_control.dart';

/// Flash (left) + live zoom readout (right). The middle spacer matches the
/// shutter so these line up with the bottom row.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.flashMode,
    required this.zoomNotifier,
    required this.onToggleFlash,
  });

  final FlashMode flashMode;
  final ValueListenable<double> zoomNotifier;
  final VoidCallback? onToggleFlash;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 8,
            left: MachineMetrics.rowPadX,
            right: MachineMetrics.rowPadX,
          ),
          child: Row(
            // Without this the Row centres itself in the full-height fill.
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CameraControl.icon(
                icon: _flashIcon(flashMode),
                onPressed: onToggleFlash,
                tooltip: 'Flash',
              ),
              const SizedBox(width: MachineMetrics.shutterSize),
              ValueListenableBuilder<double>(
                valueListenable: zoomNotifier,
                builder: (context, zoom, _) =>
                    CameraControl.label('${zoom.toStringAsFixed(1)}×'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _flashIcon(FlashMode mode) {
  switch (mode) {
    case FlashMode.always:
    case FlashMode.torch:
      return Icons.flash_on;
    case FlashMode.auto:
      return Icons.flash_auto;
    case FlashMode.off:
      return Icons.flash_off;
  }
}
