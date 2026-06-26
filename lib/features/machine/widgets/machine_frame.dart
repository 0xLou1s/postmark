import 'package:flutter/material.dart';

/// Brushed-metal machine body rendered from [assets/machine/frame.png].
///
/// The PNG has a transparent rectangular window cut into the metal bezel.
/// [slotChild] (the live viewfinder or a printed stamp) is placed *behind*
/// the image and aligned to that window — the opaque metal masks any overflow,
/// so the slot reads as recessed into the machine.
class MachineFrame extends StatelessWidget {
  const MachineFrame({super.key, required this.slotChild});
  final Widget slotChild;

  // frame.png intrinsic size: 917 x 1015.
  static const double _frameAspect = 917 / 1015;

  // Transparent window measured from the PNG's alpha channel, as a fraction
  // of the frame size (left, top, right, bottom insets).
  static const double _winLeft = 0.2508;
  static const double _winTop = 0.2552;
  static const double _winRight = 0.2443;
  static const double _winBottom = 0.2522;

  // Bleed the slot slightly under the metal so no seam shows at the edges.
  static const double _bleed = 0.006;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _frameAspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Viewfinder / stamp behind the metal, filling the window.
              Positioned(
                left: w * (_winLeft - _bleed),
                top: h * (_winTop - _bleed),
                right: w * (_winRight - _bleed),
                bottom: h * (_winBottom - _bleed),
                child: slotChild,
              ),
              // Brushed-metal body on top; its transparent window reveals
              // the slot above.
              Image.asset(
                'assets/machine/frame.png',
                fit: BoxFit.fill,
              ),
            ],
          );
        },
      ),
    );
  }
}
