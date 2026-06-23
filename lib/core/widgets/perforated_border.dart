import 'package:flutter/material.dart';

/// Number of semicircular notches that fit along a side of the given length
/// for a target notch radius. Always >= 1.
int scallopCount(double sideLength, double radius) {
  final n = (sideLength / (radius * 2)).floor();
  return n < 1 ? 1 : n;
}

/// Paints a classic stamp: white paper rectangle whose outer edge is cut into
/// even semicircular notches on all four sides, with a soft drop shadow.
/// The [child] (image) is clipped to the inner notched paper area.
class StampFrame extends StatelessWidget {
  const StampFrame({
    super.key,
    required this.child,
    this.notchRadius = 7,
    this.paperInset = 10,
  });

  final Widget child;
  final double notchRadius;
  final double paperInset; // white border thickness around the image

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StampShadowPainter(notchRadius: notchRadius),
      child: ClipPath(
        clipper: _StampClipper(notchRadius: notchRadius),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(paperInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: child,
          ),
        ),
      ),
    );
  }
}

Path _stampPath(Size size, double r) {
  final path = Path();
  final cols = scallopCount(size.width, r);
  final rows = scallopCount(size.height, r);
  final dx = size.width / cols;
  final dy = size.height / rows;

  path.moveTo(0, 0);
  // top edge, left -> right, notches dip downward (into the paper)
  for (var i = 0; i < cols; i++) {
    final cx = dx * i + dx / 2;
    path.lineTo(cx - r, 0);
    path.arcToPoint(
      Offset(cx + r, 0),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(size.width, 0);
  // right edge, top -> bottom, notches dip leftward
  for (var i = 0; i < rows; i++) {
    final cy = dy * i + dy / 2;
    path.lineTo(size.width, cy - r);
    path.arcToPoint(
      Offset(size.width, cy + r),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(size.width, size.height);
  // bottom edge, right -> left, notches dip upward
  for (var i = 0; i < cols; i++) {
    final cx = size.width - (dx * i + dx / 2);
    path.lineTo(cx + r, size.height);
    path.arcToPoint(
      Offset(cx - r, size.height),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(0, size.height);
  // left edge, bottom -> top, notches dip rightward
  for (var i = 0; i < rows; i++) {
    final cy = size.height - (dy * i + dy / 2);
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
