import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/app_durations.dart';
import 'gallery_picker.dart';
import 'machine_controller.dart';

/// Owns both capture paths — live camera and gallery — and the transient UI
/// state around them: whether a capture is in flight, whether the machine is
/// pressed down, and the image currently ejecting from the slot.
///
/// Both entry points latch [busy] themselves and refuse to run while another
/// capture is in flight. On success the caller must call [reset] once it has
/// finished with the returned bytes.
class MachineCaptureFlow extends ChangeNotifier {
  MachineCaptureFlow({required TickerProvider vsync}) {
    _ejectAnimation = AnimationController(
      vsync: vsync,
      duration: AppDurations.eject,
    );
  }

  late final AnimationController _ejectAnimation;

  Animation<double> get ejectAnimation => _ejectAnimation;

  bool _busy = false;
  bool _pressed = false;
  Uint8List? _ejectImage;
  bool _disposed = false;

  bool get busy => _busy;
  bool get pressed => _pressed;
  Uint8List? get ejectImage => _ejectImage;

  set pressed(bool value) {
    if (_disposed || _pressed == value) return;
    _pressed = value;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_disposed || _busy == value) return;
    _busy = value;
    notifyListeners();
  }

  /// Presses the machine down, captures a frame cropped to the bezel window,
  /// then releases and settles. Returns null if a capture is already running or
  /// the capture failed; the caller must call [reset] once it has finished with
  /// a successful result.
  Future<Uint8List?> captureFromCamera(
    MachineController controller, {
    required Rect? windowRect,
    required Size? screenSize,
  }) async {
    if (_busy) return null;
    _setBusy(true);

    pressed = true;
    await Future.delayed(AppDurations.pressDown);

    final bytes = (windowRect != null && screenSize != null)
        ? await controller.captureCropped(
            windowRect: windowRect,
            screenSize: screenSize,
          )
        : await controller.capture();

    pressed = false;
    if (bytes == null) {
      _setBusy(false);
      return null;
    }
    await Future.delayed(AppDurations.springBack);
    return bytes;
  }

  /// Opens the gallery. Returns null if a capture is already running or the
  /// user cancelled; the caller must call [reset] once it has finished with a
  /// successful result.
  Future<Uint8List?> pickFromGallery() async {
    if (_busy) return null;
    _setBusy(true);

    final bytes = await pickImageBytes();
    if (bytes == null) {
      _setBusy(false);
      return null;
    }
    return bytes;
  }

  /// Runs the eject animation with [bytes] showing in the slot, leaving the
  /// image on screen when it completes so the caller can navigate over it.
  Future<void> eject(Uint8List bytes) async {
    if (_disposed) return;
    _ejectImage = bytes;
    notifyListeners();
    await _ejectAnimation.forward(from: 0);
  }

  /// Clears the ejected image and releases the busy latch.
  void reset() {
    if (_disposed) return;
    _ejectImage = null;
    _busy = false;
    _ejectAnimation.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ejectAnimation.dispose();
    super.dispose();
  }
}
