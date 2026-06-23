import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Placeholder for Task 6. Receives the captured image bytes from MachineScreen.
class PrintingScreen extends StatelessWidget {
  const PrintingScreen({super.key, required this.image});

  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Print Preview')),
      body: Center(child: Image.memory(image)),
    );
  }
}
