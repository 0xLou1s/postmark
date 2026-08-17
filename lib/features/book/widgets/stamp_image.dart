import 'dart:io';

import 'package:flutter/material.dart';

/// A stamp's photo from disk.
///
/// An unreadable file shows a placeholder rather than throwing: one bad file
/// must not take down the book, and neither the row nor the bytes are touched.
class StampImage extends StatelessWidget {
  const StampImage({super.key, required this.imagePath, this.decodeWidth});

  final String imagePath;

  /// Caps the decoded bitmap for small targets like the book's grid tiles,
  /// where a full camera JPEG at native resolution is far more than is needed.
  final int? decodeWidth;

  static const _placeholderColor = Color(0xFFE8E4DC);

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: _placeholderColor,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.black26),
        ),
      ),
    );
  }
}
