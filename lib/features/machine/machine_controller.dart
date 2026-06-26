import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image/image.dart' as img;

/// Owns the CameraController lifecycle. Exposes init + capture.
class MachineController extends ChangeNotifier {
  CameraController? controller;
  bool initializing = false;
  String? error;

  double minZoom = 1.0;
  double maxZoom = 1.0;

  /// Current zoom level. Kept in a [ValueNotifier] so only the zoom badge
  /// rebuilds on change — pinching must not rebuild the camera preview/overlay.
  final ValueNotifier<double> zoomNotifier = ValueNotifier(1.0);
  double get zoom => zoomNotifier.value;

  // Coalesces rapid pinch updates into one in-flight setZoomLevel call so the
  // platform channel isn't flooded (the source of the stutter).
  double _targetZoom = 1.0;
  double _appliedZoom = 1.0;
  bool _applyingZoom = false;

  Future<void> init() async {
    if (controller != null || initializing) return;
    initializing = true;
    notifyListeners();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        error = 'No camera found on this device.';
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(back, ResolutionPreset.high,
          enableAudio: false);
      await c.initialize();
      minZoom = await c.getMinZoomLevel();
      maxZoom = await c.getMaxZoomLevel();
      zoomNotifier.value = minZoom;
      _targetZoom = minZoom;
      _appliedZoom = minZoom;
      controller = c;
    } catch (e) {
      error = e.toString();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  /// Sets the camera zoom, clamped to the supported range. Updates the badge
  /// immediately and applies the level natively without rebuilding the tree;
  /// rapid pinch updates are coalesced so the platform channel isn't flooded.
  void setZoom(double value) {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    final clamped = value.clamp(minZoom, maxZoom);
    zoomNotifier.value = clamped;
    _targetZoom = clamped;
    _drainZoom();
  }

  Future<void> _drainZoom() async {
    if (_applyingZoom) return;
    final c = controller;
    if (c == null) return;
    _applyingZoom = true;
    try {
      // Always apply the latest target; skip the intermediate values that
      // piled up while a previous setZoomLevel was in flight.
      while ((_targetZoom - _appliedZoom).abs() > 0.001) {
        _appliedZoom = _targetZoom;
        await c.setZoomLevel(_appliedZoom);
      }
    } finally {
      _applyingZoom = false;
    }
  }

  /// Captures a frame and returns its JPEG bytes.
  Future<Uint8List?> capture() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return null;
    final file = await c.takePicture();
    return file.readAsBytes();
  }

  /// Captures a full-resolution photo and crops it to exactly the part of the
  /// live preview that was visible through [windowRect] (the machine's window),
  /// given a full-screen preview rendered with [BoxFit.cover] over [screenSize].
  ///
  /// The preview and the captured photo share the same field of view, so we
  /// express the window as fractions of the cover-fitted preview and apply the
  /// same fractions to the captured image's pixels.
  Future<Uint8List?> captureCropped({
    required Rect windowRect,
    required Size screenSize,
  }) async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return null;
    final file = await c.takePicture();
    final bytes = await file.readAsBytes();

    final preview = c.value.previewSize;
    if (preview == null) return bytes;

    // previewSize is reported landscape (long side = width); the preview is
    // displayed portrait, so swap to get the on-screen source dimensions.
    final srcW = preview.height;
    final srcH = preview.width;

    // BoxFit.cover: scale the source to fill the screen, centred.
    final scale = math.max(screenSize.width / srcW, screenSize.height / srcH);
    final dispW = srcW * scale;
    final dispH = srcH * scale;
    final offX = (screenSize.width - dispW) / 2;
    final offY = (screenSize.height - dispH) / 2;

    final u0 = ((windowRect.left - offX) / dispW).clamp(0.0, 1.0);
    final v0 = ((windowRect.top - offY) / dispH).clamp(0.0, 1.0);
    final u1 = ((windowRect.right - offX) / dispW).clamp(0.0, 1.0);
    final v1 = ((windowRect.bottom - offY) / dispH).clamp(0.0, 1.0);
    if (u1 <= u0 || v1 <= v0) return bytes;

    // Decode + crop off the UI isolate — full-res JPEGs are heavy.
    return compute(_cropJpeg, _CropRequest(bytes, u0, v0, u1, v1));
  }

  @override
  void dispose() {
    zoomNotifier.dispose();
    controller?.dispose();
    super.dispose();
  }
}

/// Crop parameters as fractions [0,1] of the (orientation-baked) image.
class _CropRequest {
  const _CropRequest(this.bytes, this.u0, this.v0, this.u1, this.v1);
  final Uint8List bytes;
  final double u0, v0, u1, v1;
}

/// Runs on a background isolate via [compute]: decode, normalise orientation,
/// crop to the requested fractions, and re-encode as JPEG. Falls back to the
/// original bytes if anything is off.
Uint8List _cropJpeg(_CropRequest r) {
  final decoded = img.decodeImage(r.bytes);
  if (decoded == null) return r.bytes;
  final baked = img.bakeOrientation(decoded);

  final x = (r.u0 * baked.width).round();
  final y = (r.v0 * baked.height).round();
  final w = ((r.u1 - r.u0) * baked.width).round();
  final h = ((r.v1 - r.v0) * baked.height).round();
  if (w <= 0 || h <= 0) return r.bytes;

  final cropped = img.copyCrop(baked, x: x, y: y, width: w, height: h);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}

final machineControllerProvider =
    ChangeNotifierProvider<MachineController>((ref) {
  // ChangeNotifierProvider already disposes the returned notifier on teardown;
  // adding ref.onDispose(m.dispose) would dispose it twice and throw.
  return MachineController();
});
