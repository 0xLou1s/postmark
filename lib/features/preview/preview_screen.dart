import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Placeholder for Task 7. Displays the captured image after the printing animation.
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key, required this.image});

  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Image.memory(image)),
    );
  }
}
