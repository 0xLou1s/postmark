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
List<double> _notchCenters(double length, double r) {
  final margin = r;
  final usable = length - 2 * margin;
  if (usable <= 2 * r) return [length / 2];
  final n = (usable / (2 * r)).floor();
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
