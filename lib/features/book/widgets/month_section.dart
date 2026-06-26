import 'package:flutter/material.dart';

import '../../../domain/stamp.dart';
import 'stamp_tile.dart';

class MonthSection extends StatelessWidget {
  const MonthSection({super.key, required this.group});
  final MonthGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
          child: Text(group.label,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600)),
        ),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: kStampAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final s in group.stamps) StampTile(stamp: s)],
        ),
      ],
    );
  }
}
