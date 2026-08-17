import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/camera_capability.dart';
import 'machine_capture_flow.dart';
import 'machine_controller.dart';
import 'widgets/camera_view.dart';
import 'widgets/eject_overlay.dart';
import 'widgets/fallback_view.dart';
import '../preview/preview_screen.dart';

class MachineScreen extends ConsumerStatefulWidget {
  const MachineScreen({super.key});
  @override
  ConsumerState<MachineScreen> createState() => _MachineScreenState();
}

class _MachineScreenState extends ConsumerState<MachineScreen>
    with SingleTickerProviderStateMixin {
  late final MachineCaptureFlow _flow;
  double _baseZoom = 1.0;

  // The stack is screen-space; the window is the bezel opening to crop to.
  final _stackKey = GlobalKey();
  final _windowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _flow = MachineCaptureFlow(vsync: this)..addListener(_onFlowChanged);
    if (!usesGalleryPicker) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(machineControllerProvider).init(),
      );
    }
  }

  void _onFlowChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flow.removeListener(_onFlowChanged);
    _flow.dispose();
    super.dispose();
  }

  /// Measured at rest, before the press: the press is a visual scale only and
  /// must not skew the crop region.
  (Rect?, Size?) _measureWindow() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final windowBox =
        _windowKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || windowBox == null) return (null, null);
    final origin = stackBox.localToGlobal(Offset.zero);
    final rect =
        (windowBox.localToGlobal(Offset.zero) - origin) & windowBox.size;
    return (rect, stackBox.size);
  }

  Future<void> _onShutter() async {
    final machine = ref.read(machineControllerProvider);
    final useGallery = usesGalleryPicker || machine.error != null;

    final Uint8List? bytes;
    if (useGallery) {
      bytes = await _flow.pickFromGallery();
    } else {
      final (windowRect, screenSize) = _measureWindow();
      bytes = await _flow.captureFromCamera(
        machine,
        windowRect: windowRect,
        screenSize: screenSize,
      );
    }

    if (!mounted || bytes == null) return;
    await _ejectAndDescribe(bytes);
  }

  Future<void> _onPick() async {
    final bytes = await _flow.pickFromGallery();
    if (!mounted || bytes == null) return;
    await _ejectAndDescribe(bytes);
  }

  Future<void> _ejectAndDescribe(Uint8List bytes) async {
    await _flow.eject(bytes);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PreviewScreen(image: bytes)));
    if (!mounted) return;
    _flow.reset();
  }

  @override
  Widget build(BuildContext context) {
    final ejectImage = _flow.ejectImage;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildContent(),
        if (ejectImage != null)
          EjectOverlay(animation: _flow.ejectAnimation, image: ejectImage),
      ],
    );
  }

  Widget _buildContent() {
    if (usesGalleryPicker) {
      return FallbackView(
        ready: true,
        enabled: !_flow.busy,
        onShutter: _onShutter,
      );
    }

    final machine = ref.watch(machineControllerProvider);
    final cam = machine.controller;
    final cameraLive =
        machine.switching ||
        (machine.error == null && cam != null && cam.value.isInitialized);

    if (cameraLive) {
      return CameraView(
        machine: machine,
        stackKey: _stackKey,
        windowKey: _windowKey,
        pressed: _flow.pressed,
        busy: _flow.busy,
        onShutter: _onShutter,
        onShutterPressedChanged: (p) => _flow.pressed = p,
        onPick: _onPick,
        onFlip: machine.switchCamera,
        onToggleFlash: machine.cycleFlash,
        onZoomStart: () => _baseZoom = machine.zoom,
        onZoomUpdate: (scale) => machine.setZoom(_baseZoom * scale),
      );
    }

    final ready = machine.error != null;
    return FallbackView(
      ready: ready,
      enabled: !_flow.busy && ready,
      onShutter: _onShutter,
    );
  }
}
