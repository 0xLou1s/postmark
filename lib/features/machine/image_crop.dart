import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Crop parameters as fractions [0,1] of the (orientation-baked) image.
class CropRequest {
  const CropRequest(
    this.bytes,
    this.u0,
    this.v0,
    this.u1,
    this.v1, {
    this.flipH = false,
  });
  final Uint8List bytes;
  final double u0, v0, u1, v1;

  /// Mirror horizontally before cropping (front-camera un-mirroring).
  final bool flipH;
}

/// Runs on a background isolate via [compute]: decode, normalise orientation,
/// crop to the requested fractions, and re-encode as JPEG. Falls back to the
/// original bytes if anything is off.
Uint8List cropJpeg(CropRequest r) {
  final decoded = img.decodeImage(r.bytes);
  if (decoded == null) return r.bytes;
  var baked = img.bakeOrientation(decoded);
  // Mirror first so screen-space crop fractions (from the mirrored preview)
  // map onto the same pixels and the result matches what the user saw.
  if (r.flipH) baked = img.flipHorizontal(baked);

  final x = (r.u0 * baked.width).round();
  final y = (r.v0 * baked.height).round();
  final w = ((r.u1 - r.u0) * baked.width).round();
  final h = ((r.v1 - r.v0) * baked.height).round();
  if (w <= 0 || h <= 0) return r.bytes;

  final cropped = img.copyCrop(baked, x: x, y: y, width: w, height: h);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}
