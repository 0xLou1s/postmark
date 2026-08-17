import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/app_durations.dart';
import 'gallery_picker.dart';
import 'machine_controller.dart';

/// Owns the capture sequence and the transient UI state around it: whether a
/// capture is in flight, whether the machine is pressed down, and the image
/// currently ejecting from the slot.
class MachineCaptureFlow extends ChangeNotifier {
  MachineCaptureFlow({required this.vsync}) {
    ejectAnimation = AnimationController(
      vsync: vsync,
      duration: AppDurations.eject,
    );
  }

  final TickerProvider vsync;
  late final AnimationController ejectAnimation;

  bool _busy = false;
  bool _pressed = false;
  Uint8List? _ejectImage;

  bool get busy => _busy;
  bool get pressed => _pressed;
  Uint8List? get ejectImage => _ejectImage;

  set busy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  set pressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    notifyListeners();
  }

  /// Presses the machine down, captures a frame cropped to the bezel window,
  /// then releases and settles. Returns the captured bytes, or null if the
  /// capture failed (in which case [busy] is cleared).
  Future<Uint8List?> captureFromCamera(
    MachineController controller, {
    required Rect? windowRect,
    required Size? screenSize,
  }) async {
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
      busy = false;
      return null;
    }
    await Future.delayed(AppDurations.springBack);
    return bytes;
  }

  /// Opens the gallery. Returns the chosen bytes, or null on cancel (in which
  /// case [busy] is cleared).
  Future<Uint8List?> pickFromGallery() async {
    final bytes = await pickImageBytes();
    if (bytes == null) {
      busy = false;
      return null;
    }
    return bytes;
  }

  /// Runs the eject animation with [bytes] showing in the slot, leaving the
  /// image on screen when it completes so the caller can navigate over it.
  Future<void> eject(Uint8List bytes) async {
    _ejectImage = bytes;
    notifyListeners();
    await ejectAnimation.forward(from: 0);
  }

  /// Clears the ejected image and releases the busy latch.
  void reset() {
    _ejectImage = null;
    _busy = false;
    ejectAnimation.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    ejectAnimation.dispose();
    super.dispose();
  }
}
