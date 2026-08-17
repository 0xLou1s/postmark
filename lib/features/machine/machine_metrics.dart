import 'package:flutter/widgets.dart';

class MachineMetrics {
  /// Insets around the machine. The horizontal padding shrinks the body (the
  /// AspectRatio is width-limited) so it reads as a smaller device; the bottom
  /// padding keeps it clear of the shutter row. Shared by the live frame and the
  /// eject overlay so they sit in exactly the same place.
  static const insets = EdgeInsets.fromLTRB(46, 32, 46, 132);

  /// How far the machine shrinks while the shutter "presses" it down.
  static const double pressScale = 0.92;

  /// Diameter shared by every round on-screen control (flash, zoom, gallery,
  /// flip) so the top and bottom rows line up.
  static const double controlSize = 46;

  /// Horizontal inset of the top/bottom control rows, shared so flash lines up
  /// over the gallery button and zoom over the flip button.
  static const double rowPadX = 24;

  /// The zoom gesture stops short of the bottom so its scale recognizer can't
  /// steal taps meant for the control buttons.
  static const double zoomGestureBottomInset = 160;

  /// Width reserved between the flash button and the zoom badge, matching the
  /// shutter so the top and bottom rows align.
  static const double shutterSpacerWidth = 76;
}
