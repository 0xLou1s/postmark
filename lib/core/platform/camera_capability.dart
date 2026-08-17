import 'dart:io';

import 'package:flutter/foundation.dart';

/// Desktop has no `camera` implementation (camera_avfoundation is iOS-only), so
/// those platforms pick from the gallery instead. A device that reports no camera
/// at runtime — a simulator, say — falls back separately, in MachineScreen.
bool get usesGalleryPicker =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
