import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the system gallery. Returns null when the user cancels.
Future<Uint8List?> pickImageBytes() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  return picked.readAsBytes();
}
