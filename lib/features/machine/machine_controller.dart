import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'image_crop.dart';

/// Owns the CameraController lifecycle. Exposes init + capture.
class MachineController extends ChangeNotifier {
  CameraController? controller;
  bool initializing = false;
  String? error;

  double minZoom = 1.0;
  double maxZoom = 1.0;

  /// All cameras reported by the platform, plus which lens we're showing now.
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  /// True with multiple cameras, or before the list has loaded — [switchCamera]
  /// then loads it lazily and no-ops if there turns out to be only one.
  bool get canSwitchCamera => _cameras.isEmpty || _cameras.length > 1;
  CameraLensDirection get lensDirection => _lensDirection;
  bool switching = false;

  /// Defaults to off so the front camera never fires automatically.
  FlashMode flashMode = FlashMode.off;

  /// In a [ValueNotifier] so pinching rebuilds only the zoom badge, never the
  /// preview or overlay.
  final ValueNotifier<double> zoomNotifier = ValueNotifier(1.0);
  double get zoom => zoomNotifier.value;

  // Coalesces rapid pinch updates into one in-flight setZoomLevel call, so the
  // platform channel isn't flooded — that flooding is what caused the stutter.
  double _targetZoom = 1.0;
  double _appliedZoom = 1.0;
  bool _applyingZoom = false;

  Future<void> init() async {
    if (controller != null || initializing) return;
    initializing = true;
    notifyListeners();
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        error = 'No camera found on this device.';
        return;
      }
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      await _open(back);
    } catch (e) {
      error = e.toString();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  /// Opens [description], disposing any current controller. The caller handles
  /// error reporting and notification around it.
  Future<void> _open(CameraDescription description) async {
    await controller?.dispose();
    controller = null;
    final c = CameraController(description, ResolutionPreset.high,
        enableAudio: false);
    await c.initialize();
    minZoom = await c.getMinZoomLevel();
    maxZoom = await c.getMaxZoomLevel();
    zoomNotifier.value = minZoom;
    _targetZoom = minZoom;
    _appliedZoom = minZoom;
    _lensDirection = description.lensDirection;
    // Flash is per-controller, so re-apply on every open. Most front cameras
    // have none, so failure is expected.
    try {
      await c.setFlashMode(flashMode);
    } catch (_) {}
    controller = c;
  }

  /// Cycles the flash through off → auto → always and applies it natively.
  Future<void> cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    flashMode = order[(order.indexOf(flashMode) + 1) % order.length];
    final c = controller;
    if (c != null && c.value.isInitialized) {
      try {
        await c.setFlashMode(flashMode);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Toggles between the front and back lens. No-op while a switch is already
  /// in flight or when there's only one camera.
  Future<void> switchCamera() async {
    if (switching) return;
    switching = true;
    notifyListeners();
    try {
      // The list may be empty if the controller survived a hot reload; load it
      // on demand so the flip button keeps working without a full restart.
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.length < 2) return;
      final target = _lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final next = _cameras.firstWhere(
        (c) => c.lensDirection == target,
        orElse: () => _cameras.firstWhere(
          (c) => c.lensDirection != _lensDirection,
          orElse: () => _cameras.first,
        ),
      );
      await _open(next);
    } catch (e) {
      error = e.toString();
    } finally {
      switching = false;
      notifyListeners();
    }
  }

  /// Updates the badge immediately and applies the level natively without
  /// rebuilding the tree.
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
      // Skips the intermediate values that piled up while the previous call was
      // in flight.
      while ((_targetZoom - _appliedZoom).abs() > 0.001) {
        _appliedZoom = _targetZoom;
        await c.setZoomLevel(_appliedZoom);
      }
    } finally {
      _applyingZoom = false;
    }
  }

  /// The front preview is mirrored, so its captures must be flipped back to
  /// match what the user saw.
  bool get _isFront => _lensDirection == CameraLensDirection.front;

  /// A frame as JPEG bytes, un-mirrored for the front camera.
  Future<Uint8List?> capture() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return null;
    final file = await c.takePicture();
    final bytes = await file.readAsBytes();
    if (!_isFront) return bytes;
    return compute(cropJpeg, CropRequest(bytes, 0, 0, 1, 1, flipH: true));
  }

  /// A full-resolution photo cropped to whatever was visible through
  /// [windowRect], given a [BoxFit.cover] preview over [screenSize].
  ///
  /// Preview and photo share a field of view, so the window is expressed as
  /// fractions of the cover-fitted preview and applied to the photo's pixels.
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

    // Off the UI isolate: full-res JPEGs are heavy to decode.
    return compute(
      cropJpeg,
      CropRequest(bytes, u0, v0, u1, v1, flipH: _isFront),
    );
  }

  @override
  void dispose() {
    zoomNotifier.dispose();
    controller?.dispose();
    super.dispose();
  }
}

// ChangeNotifierProvider disposes the notifier itself; adding ref.onDispose
// would dispose it twice and throw.
final machineControllerProvider =
    ChangeNotifierProvider<MachineController>((ref) => MachineController());
