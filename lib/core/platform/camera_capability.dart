import 'dart:io';

import 'package:flutter/foundation.dart';

// macOS/desktop: camera_avfoundation is iOS-only — use image_picker instead.
// Also falls back to picker when camera reports no-camera error (e.g. simulator).
bool get usesGalleryPicker =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
