import 'package:flutter/material.dart';

import '../machine_metrics.dart';
import 'camera_control.dart';
import 'shutter_button.dart';

/// Gallery + shutter + flip, kept clear of the bottom safe area.
class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.onPick,
    required this.onShutter,
    required this.onFlip,
    required this.shutterEnabled,
    required this.onShutterPressedChanged,
  });

  final VoidCallback? onPick;
  final VoidCallback onShutter;
  final VoidCallback? onFlip;
  final bool shutterEnabled;
  final ValueChanged<bool> onShutterPressedChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MachineMetrics.rowPadX,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CameraControl.icon(
                    icon: Icons.photo_library_outlined,
                    onPressed: onPick,
                    tooltip: 'Pick from gallery',
                  ),
                  ShutterButton(
                    onPressed: onShutter,
                    enabled: shutterEnabled,
                    onPressedChanged: onShutterPressedChanged,
                  ),
                  CameraControl.icon(
                    icon: Icons.cameraswitch_outlined,
                    onPressed: onFlip,
                    tooltip: 'Switch camera',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
