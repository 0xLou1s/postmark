import 'package:flutter/material.dart';

/// Brushed-metal machine body rendered from [assets/machine/frame.png].
///
/// The PNG has a transparent rectangular window cut into the metal bezel.
/// [slotChild] (the live viewfinder or a printed stamp) is placed *behind*
/// the image and aligned to that window — the opaque metal masks any overflow,
/// so the slot reads as recessed into the machine.
class MachineFrame extends StatelessWidget {
  const MachineFrame({
    super.key,
    required this.slotChild,
    this.slotInset = -_bleed,
  });
  final Widget slotChild;

  /// Inset applied to the slot relative to the window, as a fraction of the
  /// frame size. Negative bleeds the slot *under* the bezel (good for a
  /// photo/viewfinder that should fill edge-to-edge with no rim). A positive
  /// value tucks the slot *inside* the opening so a notched stamp shows its
  /// full perforation evenly on all four sides instead of having the outer
  /// notches hidden under the (slightly asymmetric) metal window edge.
  final double slotInset;

  // frame.png intrinsic size: 917 x 1015.
  static const double _frameAspect = 917 / 1015;

  // Transparent window measured from the PNG's alpha channel, as a fraction
  // of the frame size (left, top, right, bottom insets).
  static const double _winLeft = 0.2508;
  static const double _winTop = 0.2552;
  static const double _winRight = 0.2443;
  static const double _winBottom = 0.2522;

  // The dark backing and the slot both bleed under the metal so the photo
  // fills the window edge-to-edge; the opaque bezel hides the stamp's true
  // edge (and any anti-aliasing) so no rim shows.
  static const double _bleed = 0.012;

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
              // Viewfinder / stamp. With the default negative inset it bleeds
              // under the bezel; with a positive [slotInset] it sits inside the
              // opening so a notched stamp's full perforation stays visible.
              Positioned(
                left: w * (_winLeft + slotInset),
                top: h * (_winTop + slotInset),
                right: w * (_winRight + slotInset),
                bottom: h * (_winBottom + slotInset),
                child: slotChild,
              ),
              // Brushed-metal body on top; its transparent window reveals
              // the slot above. Ignore pointers so gestures (pinch-to-zoom)
              // reach the viewfinder beneath the metal.
              IgnorePointer(
                child: Image.asset(
                  'assets/machine/frame.png',
                  fit: BoxFit.fill,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The "just printed" moment: the cut-out stamp is pushed up out of the slot
/// toward the upper-left (≈9 o'clock) and tilts as it clears the bezel, while
/// the window it left behind reads as an empty black die-cut.
///
/// [progress] runs 0→1; at 0 the [stamp] sits exactly in the window, at 1 it
/// has ejected clear of the metal.
class MachineEjectFrame extends StatelessWidget {
  const MachineEjectFrame({
    super.key,
    required this.stamp,
    required this.progress,
  });

  final Widget stamp;
  final double progress;

  static const double _frameAspect = MachineFrame._frameAspect;
  static const double _winLeft = MachineFrame._winLeft;
  static const double _winTop = MachineFrame._winTop;
  static const double _winRight = MachineFrame._winRight;
  static const double _winBottom = MachineFrame._winBottom;
  static const double _bleed = MachineFrame._bleed;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
    return AspectRatio(
      aspectRatio: _frameAspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Eject vector: lifts up and drifts left (≈9 o'clock) with a clear
          // tilt — not too high so it stays overlapping the bezel.
          final dx = -e * w * 0.14;
          final dy = -e * h * 0.34;
          final angle = -e * 0.20;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Empty black die where the stamp was cut out.
              Positioned(
                left: w * (_winLeft - _bleed),
                top: h * (_winTop - _bleed),
                right: w * (_winRight - _bleed),
                bottom: h * (_winBottom - _bleed),
                child: const ColoredBox(color: Colors.black),
              ),
              // Brushed-metal body; the stamp rides over it as it ejects.
              IgnorePointer(
                child: Image.asset('assets/machine/frame.png', fit: BoxFit.fill),
              ),
              // The cut-out stamp, seated in the window then pushed clear.
              Positioned(
                left: w * (_winLeft - _bleed),
                top: h * (_winTop - _bleed),
                right: w * (_winRight - _bleed),
                bottom: h * (_winBottom - _bleed),
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(angle: angle, child: stamp),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The machine body as a transparent overlay for a full-screen camera.
///
/// Unlike [MachineFrame], nothing is rendered behind the window: the metal
/// bezel is painted on top of whatever sits below it in the parent stack (the
/// full-screen live preview), and its transparent window simply reveals that
/// preview. [windowKey] marks the exact on-screen window rectangle so the
/// capture code can crop the photo to just this region.
class MachineOverlayFrame extends StatelessWidget {
  const MachineOverlayFrame({
    super.key,
    required this.windowKey,
    this.windowBuilder,
  });

  /// Keyed to the exact window opening so its global rect can be measured for
  /// cropping.
  final GlobalKey windowKey;

  /// Builds the stamp overlay for the window, in front of the full-screen
  /// preview but behind the bezel. It is laid out to bleed under the bezel by
  /// [bleed] on each side (so an uneven window opening shows no gap); a stamp
  /// outline should be inset by [bleed] to sit in the visible opening. Swap
  /// this to render different stamp types over the camera.
  final Widget Function(EdgeInsets bleed)? windowBuilder;

  static const double _frameAspect = MachineFrame._frameAspect;
  static const double _winLeft = MachineFrame._winLeft;
  static const double _winTop = MachineFrame._winTop;
  static const double _winRight = MachineFrame._winRight;
  static const double _winBottom = MachineFrame._winBottom;
  static const double _bleed = MachineFrame._bleed;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _frameAspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final bleed = EdgeInsets.fromLTRB(
            w * _bleed,
            h * _bleed,
            w * _bleed,
            h * _bleed,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              // Stamp overlay, bleeding under the bezel so an uneven window
              // edge never leaks the raw preview at the rim.
              if (windowBuilder != null)
                Positioned(
                  left: w * _winLeft - bleed.left,
                  top: h * _winTop - bleed.top,
                  right: w * _winRight - bleed.right,
                  bottom: h * _winBottom - bleed.bottom,
                  child: windowBuilder!(bleed),
                ),
              // Exact window opening: an empty (non-hit-testing) box keyed only
              // for measuring the crop region.
              Positioned(
                left: w * _winLeft,
                top: h * _winTop,
                right: w * _winRight,
                bottom: h * _winBottom,
                child: SizedBox.expand(key: windowKey),
              ),
              // Brushed-metal body on top; transparent window reveals the
              // full-screen preview behind the overlay. Ignore pointers so the
              // pinch-to-zoom gesture reaches the preview.
              IgnorePointer(
                child: Image.asset(
                  'assets/machine/frame.png',
                  fit: BoxFit.fill,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
