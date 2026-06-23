import 'package:flutter/material.dart';

/// Paper + brushed-metal palette. Warm, quiet, non-social.
class PostmarkColors {
  static const paper = Color(0xFFF2EFE9);
  static const ink = Color(0xFF2B2B2B);
  static const metalLight = Color(0xFFD9D9D9);
  static const metalDark = Color(0xFF8A8A8A);
  static const slot = Color(0xFF1C1C1C);
}

ThemeData buildPostmarkTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PostmarkColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: PostmarkColors.ink,
      surface: PostmarkColors.paper,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'serif',
      bodyColor: PostmarkColors.ink,
      displayColor: PostmarkColors.ink,
    ),
  );
}
