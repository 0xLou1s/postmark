import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../machine_metrics.dart';

/// A round, translucent camera control with two variants:
///   • [CameraControl.icon]  — a tappable icon button (flash / gallery / flip).
///                             Pass a null `onPressed` to render it disabled.
///   • [CameraControl.label] — a non-interactive text readout (zoom).
class CameraControl extends StatelessWidget {
  const CameraControl._({
    required this.child,
    required this.interactive,
    this.onPressed,
    this.tooltip,
  });

  /// Tappable icon button. `onPressed == null` shows it dimmed/disabled.
  factory CameraControl.icon({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return CameraControl._(
      interactive: true,
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  /// Static text readout, e.g. the current zoom "1.8×".
  factory CameraControl.label(String text) {
    return CameraControl._(
      interactive: false,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  final Widget child;
  final bool interactive;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final disabled = interactive && onPressed == null;
    Widget control = Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Container(
        width: MachineMetrics.controlSize,
        height: MachineMetrics.controlSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.controlSurface,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.controlBorder, width: 1),
          ),
        ),
        child: child,
      ),
    );

    if (!interactive) return control;

    control = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: control,
    );
    return tooltip == null
        ? control
        : Tooltip(message: tooltip!, child: control);
  }
}
