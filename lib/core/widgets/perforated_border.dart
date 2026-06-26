import 'package:flutter/material.dart';

/// Number of semicircular notches that fit along a side of the given length
/// for a target notch radius. Always >= 1.
int scallopCount(double sideLength, double radius) {
  final n = (sideLength / (radius * 2)).floor();
  return n < 1 ? 1 : n;
}

/// A classic stamp whose outer edge is cut into even semicircular notches on
/// all four sides, with a soft drop shadow. The [child] (image) fills the
/// whole stamp and the notches bite directly into it — there is no paper
/// border. The notches reveal whatever sits behind the stamp (the dark
/// machine recess, or the paper background).
class StampFrame extends StatelessWidget {
  const StampFrame({
    super.key,
    required this.child,
    this.notchRadius = 7,
  });

  final Widget child;
  final double notchRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StampShadowPainter(notchRadius: notchRadius),
      child: ClipPath(
        clipper: _StampClipper(notchRadius: notchRadius),
        child: child,
      ),
    );
  }
}

/// Centres of the notches along an edge of [length], leaving a flat margin of
/// at least [r] at each corner so the stamp keeps square (un-bitten) corners.
/// Notches are spaced [_notchSpacing] diameters apart, so a flat gap of paper
/// shows between them.
const double _notchSpacing = 1.5;

List<double> _notchCenters(double length, double r) {
  final margin = r;
  final usable = length - 2 * margin;
  final pitch = 2 * r * _notchSpacing;
  if (usable <= pitch) return [length / 2];
  final n = (usable / pitch).floor();
  final spacing = usable / n;
  return [for (var i = 0; i < n; i++) margin + spacing * (i + 0.5)];
}

Path _stampPath(Size size, double r) {
  final path = Path();
  final xs = _notchCenters(size.width, r);
  final ys = _notchCenters(size.height, r);

  path.moveTo(0, 0);
  // top edge, left -> right, notches dip downward (into the paper)
  for (final cx in xs) {
    path.lineTo(cx - r, 0);
    path.arcToPoint(
      Offset(cx + r, 0),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(size.width, 0);
  // right edge, top -> bottom, notches dip leftward
  for (final cy in ys) {
    path.lineTo(size.width, cy - r);
    path.arcToPoint(
      Offset(size.width, cy + r),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(size.width, size.height);
  // bottom edge, right -> left, notches dip upward
  for (final cx in xs.reversed) {
    path.lineTo(cx + r, size.height);
    path.arcToPoint(
      Offset(cx - r, size.height),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(0, size.height);
  // left edge, bottom -> top, notches dip rightward
  for (final cy in ys.reversed) {
    path.lineTo(0, cy + r);
    path.arcToPoint(
      Offset(0, cy - r),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.close();
  return path;
}

/// A stamp-shaped frame for a live viewfinder: the perforation is *painted*
/// (in [color]) around the edges, over whatever sits behind it (e.g. the
/// camera preview), while the stamp interior stays transparent. Unlike
/// [StampFrame] it clips nothing — it just draws the notched border — so it can
/// be laid over a full-screen preview. Drawn entirely in code so different
/// stamp outlines can be swapped in later for other stamp types.
class StampNotchOverlay extends StatelessWidget {
  const StampNotchOverlay({
    super.key,
    this.notchRadius = 8,
    this.color = const Color(0xFF141414),
    this.bleed = EdgeInsets.zero,
  });

  final double notchRadius;
  final Color color;

  /// How far the opaque border extends *beyond* the stamp outline on each side.
  /// The stamp is drawn inset by [bleed]; the extra margin is filled with
  /// [color] so it can bleed under a frame/bezel and hide any gap if the
  /// frame's window opening is slightly uneven.
  final EdgeInsets bleed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _NotchBorderPainter(
          notchRadius: notchRadius,
          color: color,
          bleed: bleed,
        ),
      ),
    );
  }
}

class _NotchBorderPainter extends CustomPainter {
  _NotchBorderPainter({
    required this.notchRadius,
    required this.color,
    required this.bleed,
  });
  final double notchRadius;
  final Color color;
  final EdgeInsets bleed;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    // Stamp outline, inset by [bleed] so the surrounding margin stays opaque.
    final stampSize = Size(
      size.width - bleed.horizontal,
      size.height - bleed.vertical,
    );
    final stamp =
        _stampPath(stampSize, notchRadius).shift(Offset(bleed.left, bleed.top));
    // Fill everything outside the stamp outline (bleed margin + the scalloped
    // notches); the stamp interior stays clear so the preview reads through.
    final border = Path.combine(PathOperation.difference, outer, stamp);
    canvas.drawPath(
      border,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_NotchBorderPainter old) =>
      old.notchRadius != notchRadius ||
      old.color != color ||
      old.bleed != bleed;
}

class _StampClipper extends CustomClipper<Path> {
  _StampClipper({required this.notchRadius});
  final double notchRadius;

  @override
  Path getClip(Size size) => _stampPath(size, notchRadius);

  @override
  bool shouldReclip(_StampClipper old) => old.notchRadius != notchRadius;
}

class _StampShadowPainter extends CustomPainter {
  _StampShadowPainter({required this.notchRadius});
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _stampPath(size, notchRadius);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.4), 6, false);
  }

  @override
  bool shouldRepaint(_StampShadowPainter old) =>
      old.notchRadius != notchRadius;
}
