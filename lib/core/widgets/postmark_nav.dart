import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A seamless bottom navigation bar that anchors to the very bottom of the
/// screen (filling the home-indicator gap) with two destinations.
///
/// Mirrors the brushed-paper aesthetic: a warm paper surface with a thin
/// hairline on top and a single raised "thumb" that glides between the
/// active destination.
class PostmarkNav extends StatelessWidget {
  const PostmarkNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_NavItem>[
    _NavItem(label: 'Stamp'),
    _NavItem(label: 'Book'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: const Border(
          top: BorderSide(color: AppColors.metalLight, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // Reserve the home-indicator area as part of the bar (no white gap),
      // while keeping the touch targets above it.
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 10 + bottomInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / _items.length;

          return SizedBox(
            height: 56,
            child: Stack(
              children: [
                // The gliding raised thumb behind the active segment.
                AnimatedAlign(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    _items.length == 1
                        ? 0
                        : (currentIndex * 2 / (_items.length - 1)) - 1,
                    0,
                  ),
                  child: Container(
                    width: segmentWidth - 12,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.metalLight.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _NavSegment(
                          label: _items[i].label,
                          selected: currentIndex == i,
                          onTap: () => onTap(i),
                          iconBuilder: i == 0
                              ? (color) => CustomPaint(
                                    size: const Size(24, 24),
                                    painter: _SealPainter(color: color),
                                  )
                              : (color) =>
                                  Icon(Icons.book, color: color, size: 24),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label});
  final String label;
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
    final color = selected ? AppColors.ink : AppColors.metalDark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active icon lifts and grows just a touch.
            AnimatedScale(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              scale: selected ? 1.08 : 1.0,
              child: iconBuilder(color),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: selected ? 0.2 : 0,
              ),
              child: Text(label),
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
