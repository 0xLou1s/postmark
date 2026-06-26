import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Brushed-metal machine body with a dark recessed slot that hosts [slotChild]
/// (the live viewfinder or a printed stamp).
class MachineFrame extends StatelessWidget {
  const MachineFrame({super.key, required this.slotChild});
  final Widget slotChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(48),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PostmarkColors.metalLight, PostmarkColors.metalDark],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color: PostmarkColors.slot,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: slotChild,
        ),
      ),
    );
  }
}
