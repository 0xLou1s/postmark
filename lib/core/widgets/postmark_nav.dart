import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A pill-shaped segmented navigation bar with two destinations.
///
/// Mirrors the brushed-paper aesthetic: a soft grey track with a single
/// raised "thumb" highlighting the active destination.
class PostmarkNav extends StatelessWidget {
  const PostmarkNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE3),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavSegment(
            label: 'Stamp',
            selected: currentIndex == 0,
            onTap: () => onTap(0),
            iconBuilder: (color) => CustomPaint(
              size: const Size(24, 24),
              painter: _SealPainter(color: color),
            ),
          ),
          _NavSegment(
            label: 'Book',
            selected: currentIndex == 1,
            onTap: () => onTap(1),
            iconBuilder: (color) => Icon(Icons.book, color: color, size: 24),
          ),
        ],
      ),
    );
  }
}

class _NavSegment extends StatelessWidget {
  const _NavSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.iconBuilder,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget Function(Color color) iconBuilder;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PostmarkColors.ink : PostmarkColors.metalDark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PostmarkColors.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconBuilder(color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a scalloped wax-seal / postmark badge — the "Stamp" glyph.
class _SealPainter extends CustomPainter {
  _SealPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.82; // depth of the scallop notches
    const scallops = 12;

    final path = Path();
    const steps = scallops * 2;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = t * 2 * math.pi - math.pi / 2;
      // alternate between outer (bump) and inner (notch) radius
      final r = i.isEven ? outer : inner;
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.color != color;
}
