import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Owns the CameraController lifecycle. Exposes init + capture.
class MachineController extends ChangeNotifier {
  CameraController? controller;
  bool initializing = false;
  String? error;

  Future<void> init() async {
    if (controller != null || initializing) return;
    initializing = true;
    notifyListeners();
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(back, ResolutionPreset.high,
          enableAudio: false);
      await c.initialize();
      controller = c;
    } catch (e) {
      error = e.toString();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  /// Captures a frame and returns its JPEG bytes.
  Future<Uint8List?> capture() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return null;
    final file = await c.takePicture();
    return file.readAsBytes();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

final machineControllerProvider =
    ChangeNotifierProvider<MachineController>((ref) {
  final m = MachineController();
  ref.onDispose(m.dispose);
  return m;
});
