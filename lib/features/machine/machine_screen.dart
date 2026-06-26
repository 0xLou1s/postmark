import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/perforated_border.dart';
import 'machine_controller.dart';
import 'widgets/machine_frame.dart';
import 'widgets/shutter_button.dart';
import '../printing/printing_screen.dart';

// macOS/desktop: camera_avfoundation is iOS-only — use image_picker instead.
// Also falls back to picker when camera reports no-camera error (e.g. simulator).
bool get _usePicker =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

class MachineScreen extends ConsumerStatefulWidget {
  const MachineScreen({super.key});
  @override
  ConsumerState<MachineScreen> createState() => _MachineScreenState();
}

class _MachineScreenState extends ConsumerState<MachineScreen> {
  bool _busy = false;
  double _baseZoom = 1.0; // camera zoom at the start of a pinch gesture

  // Keys for the full-screen layout: the stack defines screen-space, the
  // window marks the bezel opening we crop the captured photo to.
  final _stackKey = GlobalKey();
  final _windowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!_usePicker) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(machineControllerProvider).init(),
      );
    }
  }

  Future<void> _onShutter() async {
    if (_busy) return;
    setState(() => _busy = true);

    final hasError = !_usePicker &&
        ref.read(machineControllerProvider).error != null;

    if (_usePicker || hasError) {
      // macOS / desktop / no-camera (simulator): pick from gallery
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      setState(() => _busy = false);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PrintingScreen(image: bytes)),
      );
    } else {
      // iOS / Android: live full-screen capture, cropped to the bezel window.
      final stackBox =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final windowBox =
          _windowKey.currentContext?.findRenderObject() as RenderBox?;

      Uint8List? bytes;
      if (stackBox != null && windowBox != null) {
        final origin = stackBox.localToGlobal(Offset.zero);
        final windowRect =
            (windowBox.localToGlobal(Offset.zero) - origin) & windowBox.size;
        bytes = await ref.read(machineControllerProvider).captureCropped(
              windowRect: windowRect,
              screenSize: stackBox.size,
            );
      } else {
        bytes = await ref.read(machineControllerProvider).capture();
      }

      if (!mounted) return;
      setState(() => _busy = false);
      if (bytes == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PrintingScreen(image: bytes!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // iOS / Android with a live camera: full-screen viewfinder.
    if (!_usePicker) {
      final m = ref.watch(machineControllerProvider);
      final cam = m.controller;
      if (m.error == null && cam != null && cam.value.isInitialized) {
        return _buildLiveCamera(m, cam);
      }
    }
    return _buildFallback();
  }

  /// Full-screen live preview with the machine bezel overlaid; the photo is
  /// cropped to the bezel window on capture.
  Widget _buildLiveCamera(MachineController m, CameraController cam) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview, filling the screen edge-to-edge.
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cam.value.previewSize!.height,
              height: cam.value.previewSize!.width,
              child: CameraPreview(cam),
            ),
          ),
          // Pinch-to-zoom over the whole screen (the bezel ignores pointers).
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: (_) =>
                _baseZoom = ref.read(machineControllerProvider).zoom,
            onScaleUpdate: (d) => ref
                .read(machineControllerProvider)
                .setZoom(_baseZoom * d.scale),
          ),
          // Machine bezel, centred; its transparent window marks the crop area.
          Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 132),
            child: Center(
              child: MachineOverlayFrame(
                windowKey: _windowKey,
                // Stamp perforation drawn in code over the live preview; its
                // dark border bleeds under the bezel to hide any rim gap.
                windowBuilder: (bleed) => StampNotchOverlay(bleed: bleed),
              ),
            ),
          ),
          // Zoom badge + shutter, kept clear of the bottom safe area.
          Positioned.fill(
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Only the badge rebuilds while pinching, not the preview.
                  ValueListenableBuilder<double>(
                    valueListenable: m.zoomNotifier,
                    builder: (context, zoom, _) => zoom > m.minZoom
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ZoomBadge(zoom: zoom),
                          )
                        : const SizedBox.shrink(),
                  ),
                  ShutterButton(
                    onPressed: _onShutter,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// macOS / desktop / simulator (no live camera): static bezel + pick hint.
  Widget _buildFallback() {
    final mState = _usePicker ? null : ref.watch(machineControllerProvider);
    final cam = mState?.controller;
    final cameraReady = _usePicker ||
        mState?.error != null ||
        (cam != null && cam.value.isInitialized);

    final Widget viewfinder = cameraReady
        ? StampFrame(
            child: Container(
              color: const Color(0xFF1C1C1C),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white38, size: 48),
                    SizedBox(height: 12),
                    Text('Press shutter\nto pick a photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: MachineFrame(slotChild: viewfinder),
                ),
              ),
            ),
            ShutterButton(
              onPressed: _onShutter,
              enabled: !_busy && cameraReady,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing the current camera zoom, e.g. "1.8×".
class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.zoom});
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${zoom.toStringAsFixed(1)}×',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
