import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/widgets/perforated_border.dart';
import '../machine_controller.dart';
import '../machine_metrics.dart';
import 'camera_bottom_bar.dart';
import 'camera_top_bar.dart';
import 'machine_frame.dart';

/// Full-screen live preview with the machine bezel overlaid; the photo is
/// cropped to the bezel window on capture.
class CameraView extends StatelessWidget {
  const CameraView({
    super.key,
    required this.machine,
    required this.stackKey,
    required this.windowKey,
    required this.pressed,
    required this.busy,
    required this.onShutter,
    required this.onShutterPressedChanged,
    required this.onPick,
    required this.onFlip,
    required this.onToggleFlash,
    required this.onZoomStart,
    required this.onZoomUpdate,
  });

  final MachineController machine;
  final GlobalKey stackKey;
  final GlobalKey windowKey;
  final bool pressed;
  final bool busy;
  final VoidCallback onShutter;
  final ValueChanged<bool> onShutterPressedChanged;
  final VoidCallback onPick;
  final VoidCallback onFlip;
  final VoidCallback onToggleFlash;
  final VoidCallback onZoomStart;
  final ValueChanged<double> onZoomUpdate;

  @override
  Widget build(BuildContext context) {
    final cam = machine.controller;
    // While flipping lenses the old controller is disposed before the new one
    // is ready — keep the bezel + controls, but show black/loading in place of
    // the preview so we never render CameraPreview against a disposed camera.
    final showPreview =
        !machine.switching && cam != null && cam.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: stackKey,
        fit: StackFit.expand,
        children: [
          if (showPreview)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cam.value.previewSize!.height,
                height: cam.value.previewSize!.width,
                child: CameraPreview(cam),
              ),
            )
          else
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MachineMetrics.zoomGestureBottomInset,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (_) => onZoomStart(),
              onScaleUpdate: (d) => onZoomUpdate(d.scale),
            ),
          ),
          Padding(
            padding: MachineMetrics.insets,
            child: Center(
              child: AnimatedScale(
                scale: pressed ? MachineMetrics.pressScale : 1,
                duration: AppDurations.pressAnim,
                curve: Curves.easeOutCubic,
                child: MachineOverlayFrame(
                  windowKey: windowKey,
                  // Stamp perforation drawn in code over the live preview; its
                  // dark border bleeds under the bezel to hide any rim gap.
                  windowBuilder: (bleed) => StampNotchOverlay(bleed: bleed),
                ),
              ),
            ),
          ),
          CameraTopBar(
            flashMode: machine.flashMode,
            zoomNotifier: machine.zoomNotifier,
            onToggleFlash: (busy || machine.switching) ? null : onToggleFlash,
          ),
          CameraBottomBar(
            onPick: busy ? null : onPick,
            onShutter: onShutter,
            onFlip: (busy || machine.switching || !machine.canSwitchCamera)
                ? null
                : onFlip,
            shutterEnabled: !busy && !machine.switching,
            onShutterPressedChanged: onShutterPressedChanged,
          ),
        ],
      ),
    );
  }
}
