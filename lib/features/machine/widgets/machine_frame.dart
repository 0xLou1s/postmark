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

  // The dark backing bleeds under the metal so no seam shows at the window
  // edge. The slot itself is kept *inside* the opening so bright content (a
  // live camera) never leaks through the bezel's anti-aliased inner edge.
  static const double _bleed = 0.012;
  static const double _slotInset = 0.004;

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
              // Dark recess: bleeds under the bezel on every side so the
              // window edge always reads as the dark machine slot.
              Positioned(
                left: w * (_winLeft - _bleed),
                top: h * (_winTop - _bleed),
                right: w * (_winRight - _bleed),
                bottom: h * (_winBottom - _bleed),
                child: const ColoredBox(color: Color(0xFF141414)),
              ),
              // Viewfinder / stamp, kept just inside the opening. Its notches
              // reveal the dark recess behind.
              Positioned(
                left: w * (_winLeft + _slotInset),
                top: h * (_winTop + _slotInset),
                right: w * (_winRight + _slotInset),
                bottom: h * (_winBottom + _slotInset),
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
