import 'package:flutter/material.dart';

/// Geometry of `assets/machine/frame.png` — the brushed-metal body with a
/// transparent window cut into it. Measured from the PNG's alpha channel as
/// fractions of the frame size, and shared by all three frame widgets.
abstract final class _Window {
  /// frame.png intrinsic size: 917 x 1015.
  static const aspect = 917 / 1015;

  static const left = 0.2508;
  static const top = 0.2552;
  static const right = 0.2443;
  static const bottom = 0.2522;

  /// How far the slot extends under the metal, hiding the stamp's true edge (and
  /// any anti-aliasing) so no rim shows at the window.
  static const bleed = 0.012;

  /// The window, grown by [inset] on every side as a fraction of the frame.
  static Positioned fill({
    required double width,
    required double height,
    required double inset,
    required Widget child,
  }) =>
      Positioned(
        left: width * (left - inset),
        top: height * (top - inset),
        right: width * (right - inset),
        bottom: height * (bottom - inset),
        child: child,
      );
}

const _recessColor = Color(0xFF141414);

Widget _frameImage() => IgnorePointer(
      // Ignores pointers so pinch-to-zoom reaches the viewfinder beneath.
      child: Image.asset('assets/machine/frame.png', fit: BoxFit.fill),
    );

/// Machine body with [slotChild] placed behind its window — the opaque metal
/// masks any overflow, so the slot reads as recessed into the machine.
class MachineFrame extends StatelessWidget {
  const MachineFrame({
    super.key,
    required this.slotChild,
    this.slotInset = _Window.bleed,
  });

  final Widget slotChild;

  /// How far the slot bleeds under the bezel, as a fraction of the frame size.
  /// Zero or negative tucks the slot *inside* the opening instead, so a notched
  /// stamp shows its full perforation rather than losing the outer notches under
  /// the (slightly asymmetric) metal edge.
  final double slotInset;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _Window.aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              _Window.fill(
                width: w,
                height: h,
                inset: _Window.bleed,
                child: const ColoredBox(color: _recessColor),
              ),
              _Window.fill(
                width: w,
                height: h,
                inset: slotInset,
                child: slotChild,
              ),
              _frameImage(),
            ],
          );
        },
      ),
    );
  }
}

/// The "just printed" moment: the cut-out stamp is pushed up and to the left out
/// of the slot, tilting as it clears the bezel, leaving an empty black die-cut.
///
/// [progress] runs 0→1; at 0 the [stamp] sits in the window, at 1 it has ejected
/// clear of the metal.
class MachineEjectFrame extends StatelessWidget {
  const MachineEjectFrame({
    super.key,
    required this.stamp,
    required this.progress,
  });

  final Widget stamp;
  final double progress;

  // Lifts up and drifts left (≈9 o'clock), staying low enough to keep
  // overlapping the bezel.
  static const _driftX = -0.14;
  static const _driftY = -0.34;
  static const _tilt = -0.20;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
    return AspectRatio(
      aspectRatio: _Window.aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              _Window.fill(
                width: w,
                height: h,
                inset: _Window.bleed,
                child: const ColoredBox(color: Colors.black),
              ),
              _frameImage(),
              // Over the metal, so the stamp rides clear of the machine.
              _Window.fill(
                width: w,
                height: h,
                inset: _Window.bleed,
                child: Transform.translate(
                  offset: Offset(e * w * _driftX, e * h * _driftY),
                  child: Transform.rotate(angle: e * _tilt, child: stamp),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The machine body as an overlay for a full-screen camera: nothing is rendered
/// behind the window, so the bezel's transparent opening simply reveals the live
/// preview sitting below it in the parent stack.
class MachineOverlayFrame extends StatelessWidget {
  const MachineOverlayFrame({
    super.key,
    required this.windowKey,
    this.windowBuilder,
  });

  /// Marks the exact window rectangle so capture can crop the photo to it.
  final GlobalKey windowKey;

  /// Builds the stamp overlay for the window, in front of the preview but behind
  /// the bezel. It is laid out to bleed under the bezel by the given insets; a
  /// stamp outline should be inset by them to sit in the visible opening.
  final Widget Function(EdgeInsets bleed)? windowBuilder;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _Window.aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final bleed = EdgeInsets.symmetric(
            horizontal: w * _Window.bleed,
            vertical: h * _Window.bleed,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              if (windowBuilder != null)
                _Window.fill(
                  width: w,
                  height: h,
                  inset: _Window.bleed,
                  child: windowBuilder!(bleed),
                ),
              // Empty, non-hit-testing box keyed only for measuring the crop.
              _Window.fill(
                width: w,
                height: h,
                inset: 0,
                child: SizedBox.expand(key: windowKey),
              ),
              _frameImage(),
            ],
          );
        },
      ),
    );
  }
}
