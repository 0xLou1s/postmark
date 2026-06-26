import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/widgets/perforated_border.dart';
import '../preview/preview_screen.dart';

/// Freezes the captured photo, then animates the stamp ejecting upward out of
/// the machine slot, then reveals the Preview screen.
class PrintingScreen extends StatefulWidget {
  const PrintingScreen({super.key, required this.image});
  final Uint8List image;

  @override
  State<PrintingScreen> createState() => _PrintingScreenState();
}

class _PrintingScreenState extends State<PrintingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _flash;
  late final Animation<double> _eject;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _flash = CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.12, curve: Curves.easeOut));
    _eject = CurvedAnimation(
        parent: _c, curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack));
    _c.forward().whenComplete(_goToPreview);
  }

  void _goToPreview() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PreviewScreen(image: widget.image)),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final dy = (1 - _eject.value) * 220; // slides up into place
          final scale = 0.85 + _eject.value * 0.15;
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: 240,
                      height: 320,
                      child: StampFrame(
                        child: Image.memory(widget.image, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: (1 - _flash.value).clamp(0.0, 1.0) *
                      (_c.value < 0.12 ? 1 : 0),
                  child: Container(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
