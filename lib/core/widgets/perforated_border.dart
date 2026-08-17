import 'package:flutter/material.dart';

/// A stamp whose edge is cut into semicircular notches on all four sides, with
/// a soft drop shadow. The [child] fills the whole stamp and the notches bite
/// into it, revealing whatever sits behind — there is no paper border.
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

/// Notch pitch in diameters, so a flat gap shows between notches.
const double _notchSpacing = 1.5;

/// Notch centres along an edge of [length], keeping a flat margin of [r] at each
/// corner so the stamp's corners stay square.
List<double> _notchCenters(double length, double r) {
  final margin = r;
  final usable = length - 2 * margin;
  final pitch = 2 * r * _notchSpacing;
  if (usable <= pitch) return [length / 2];
  final n = (usable / pitch).floor();
  final spacing = usable / n;
  return [for (var i = 0; i < n; i++) margin + spacing * (i + 0.5)];
}

/// Walks the four edges clockwise from the top-left, biting a notch inward at
/// each centre.
Path _stampPath(Size size, double r) {
  final path = Path();
  final xs = _notchCenters(size.width, r);
  final ys = _notchCenters(size.height, r);

  path.moveTo(0, 0);
  for (final cx in xs) {
    path.lineTo(cx - r, 0);
    path.arcToPoint(
      Offset(cx + r, 0),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(size.width, 0);
  for (final cy in ys) {
    path.lineTo(size.width, cy - r);
    path.arcToPoint(
      Offset(size.width, cy + r),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(size.width, size.height);
  for (final cx in xs.reversed) {
    path.lineTo(cx + r, size.height);
    path.arcToPoint(
      Offset(cx - r, size.height),
      radius: Radius.circular(r),
      clockwise: false,
    );
  }
  path.lineTo(0, size.height);
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

/// A stamp outline for a live viewfinder: the perforation is *painted* around
/// the edges while the interior stays transparent. Unlike [StampFrame] it clips
/// nothing, so it can be laid over a full-screen preview.
class StampNotchOverlay extends StatelessWidget {
  const StampNotchOverlay({
    super.key,
    this.notchRadius = 8,
    this.color = const Color(0xFF141414),
    this.bleed = EdgeInsets.zero,
  });

  final double notchRadius;
  final Color color;

  /// How far the border extends beyond the stamp outline, so it can bleed under
  /// a bezel and hide any gap at an uneven window opening.
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
    final stampSize = Size(
      size.width - bleed.horizontal,
      size.height - bleed.vertical,
    );
    final stamp =
        _stampPath(stampSize, notchRadius).shift(Offset(bleed.left, bleed.top));
    // Everything outside the outline; the interior stays clear for the preview.
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
