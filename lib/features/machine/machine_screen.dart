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
import '../preview/preview_screen.dart';

// macOS/desktop: camera_avfoundation is iOS-only — use image_picker instead.
// Also falls back to picker when camera reports no-camera error (e.g. simulator).
bool get _usePicker =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// Insets around the machine. The horizontal padding shrinks the body (the
/// AspectRatio is width-limited) so it reads as a smaller device; the bottom
/// padding keeps it clear of the shutter row. Shared by the live frame and the
/// eject overlay so they sit in exactly the same place.
const EdgeInsets _kMachineInsets = EdgeInsets.fromLTRB(46, 32, 46, 132);

/// How far the machine shrinks while the shutter "presses" it down.
const double _kPressScale = 0.92;

/// Timings for the capture sequence — deliberate but a touch snappier.
const Duration _kPressAnim = Duration(milliseconds: 440); // scale down/up
const Duration _kPressDown = Duration(milliseconds: 440); // hold while pressed
const Duration _kSpringBack = Duration(
  milliseconds: 340,
); // settle before eject

class MachineScreen extends ConsumerStatefulWidget {
  const MachineScreen({super.key});
  @override
  ConsumerState<MachineScreen> createState() => _MachineScreenState();
}

class _MachineScreenState extends ConsumerState<MachineScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _shutterPressed = false; // press the machine frame down while held
  double _baseZoom = 1.0; // camera zoom at the start of a pinch gesture

  // Drives the freshly-stamped photo ejecting up out of the machine slot.
  late final AnimationController _ejectC;
  Uint8List? _ejectImage;

  // Keys for the full-screen layout: the stack defines screen-space, the
  // window marks the bezel opening we crop the captured photo to.
  final _stackKey = GlobalKey();
  final _windowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ejectC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    if (!_usePicker) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(machineControllerProvider).init(),
      );
    }
  }

  @override
  void dispose() {
    _ejectC.dispose();
    super.dispose();
  }

  Future<void> _onShutter() async {
    if (_busy) return;
    setState(() => _busy = true);

    final hasError =
        !_usePicker && ref.read(machineControllerProvider).error != null;

    if (_usePicker || hasError) {
      // macOS / desktop / no-camera (simulator): pick from gallery
      await _pickFromGallery();
    } else {
      // iOS / Android: live full-screen capture, cropped to the bezel window.
      // Measure the window at rest (scale 1) BEFORE pressing — the press is a
      // visual scale only and must not skew the crop region.
      final stackBox =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final windowBox =
          _windowKey.currentContext?.findRenderObject() as RenderBox?;
      Rect? windowRect;
      Size? screenSize;
      if (stackBox != null && windowBox != null) {
        final origin = stackBox.localToGlobal(Offset.zero);
        windowRect =
            (windowBox.localToGlobal(Offset.zero) - origin) & windowBox.size;
        screenSize = stackBox.size;
      }

      // 1) Press the machine down — a slow, deliberate "stamping" step.
      setState(() => _shutterPressed = true);
      await Future.delayed(_kPressDown);
      if (!mounted) return;

      // 2) Capture while pressed (using the at-rest window geometry).
      final m = ref.read(machineControllerProvider);
      final bytes = (windowRect != null && screenSize != null)
          ? await m.captureCropped(
              windowRect: windowRect,
              screenSize: screenSize,
            )
          : await m.capture();
      if (!mounted) return;

      // 3) Release; let it spring back before the stamp ejects.
      setState(() => _shutterPressed = false);
      if (bytes == null) {
        setState(() => _busy = false);
        return;
      }
      await Future.delayed(_kSpringBack);
      if (!mounted) return;
      await _printAndDescribe(bytes);
    }
  }

  /// Ejects the freshly-stamped photo up out of the slot, then opens the
  /// description screen directly (no separate printing screen). Keeps [_busy]
  /// set throughout; clears it when the user returns.
  Future<void> _printAndDescribe(Uint8List bytes) async {
    setState(() => _ejectImage = bytes);
    await _ejectC.forward(from: 0);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PreviewScreen(image: bytes)));
    if (!mounted) return;
    setState(() {
      _ejectImage = null;
      _busy = false;
    });
    _ejectC.reset();
  }

  /// Tapped the gallery button directly (mobile live camera): pick a photo
  /// instead of capturing one.
  Future<void> _onPickPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _pickFromGallery();
  }

  /// Opens the system gallery and routes the chosen image into printing.
  /// Assumes [_busy] is already set by the caller; clears it when done.
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (picked == null) {
      setState(() => _busy = false);
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    await _printAndDescribe(bytes);
  }

  Future<void> _onFlipCamera() async {
    if (_busy) return;
    await ref.read(machineControllerProvider).switchCamera();
  }

  Future<void> _onToggleFlash() async {
    await ref.read(machineControllerProvider).cycleFlash();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildContent(),
        // The freshly-stamped photo ejecting out of the slot, over everything.
        if (_ejectImage != null) _buildEjectOverlay(),
      ],
    );
  }

  Widget _buildContent() {
    // iOS / Android with a live camera: full-screen viewfinder.
    if (!_usePicker) {
      final m = ref.watch(machineControllerProvider);
      final cam = m.controller;
      // While flipping lenses the old controller is disposed before the new one
      // is ready — keep the bezel + controls, but show black/loading in place of
      // the preview so we never render CameraPreview against a disposed camera.
      if (m.switching) {
        return _buildLiveCamera(m, cam, switching: true);
      }
      if (m.error == null && cam != null && cam.value.isInitialized) {
        return _buildLiveCamera(m, cam);
      }
    }
    return _buildFallback();
  }

  /// The cut-out stamp ejecting up out of the slot over the bezel, with the
  /// window left black. Anchored to the same spot as the live frame so it
  /// reads as the same machine. Parent routes on when [_ejectC] completes.
  Widget _buildEjectOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _ejectC,
        builder: (context, _) {
          final t = _ejectC.value.clamp(0.0, 1.0);
          return ColoredBox(
            color: Colors.black.withValues(alpha: 0.35 * t),
            child: Padding(
              padding: _kMachineInsets,
              child: Center(
                child: MachineEjectFrame(
                  progress: t,
                  stamp: StampFrame(
                    child: Image.memory(_ejectImage!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Full-screen live preview with the machine bezel overlaid; the photo is
  /// cropped to the bezel window on capture.
  Widget _buildLiveCamera(
    MachineController m,
    CameraController? cam, {
    bool switching = false,
  }) {
    final showPreview = !switching && cam != null && cam.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview, filling the screen edge-to-edge. While
          // flipping lenses, show black + a spinner here instead.
          if (showPreview)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cam.value.previewSize!.height,
                height: cam.value.previewSize!.width,
                child: CameraPreview(cam),
              ),
            )
          else
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          // Pinch-to-zoom over the viewfinder. Stops short of the bottom so its
          // scale recognizer can't steal taps meant for the control buttons.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 160,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (_) =>
                  _baseZoom = ref.read(machineControllerProvider).zoom,
              onScaleUpdate: (d) => ref
                  .read(machineControllerProvider)
                  .setZoom(_baseZoom * d.scale),
            ),
          ),
          // Machine bezel, centred; its transparent window marks the crop area.
          // Presses down a touch while the shutter is held.
          Padding(
            padding: _kMachineInsets,
            child: Center(
              child: AnimatedScale(
                scale: _shutterPressed ? _kPressScale : 1,
                duration: _kPressAnim,
                curve: Curves.easeOutCubic,
                child: MachineOverlayFrame(
                  windowKey: _windowKey,
                  // Stamp perforation drawn in code over the live preview; its
                  // dark border bleeds under the bezel to hide any rim gap.
                  windowBuilder: (bleed) => StampNotchOverlay(bleed: bleed),
                ),
              ),
            ),
          ),
          // Top bar: flash (left) + live zoom readout (right). The middle
          // spacer matches the shutter so these line up with the bottom row.
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  left: _kRowPadX,
                  right: _kRowPadX,
                ),
                child: Row(
                  // Pin to the top edge; without this the Row centres itself in
                  // the full-height Positioned.fill.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CameraControl.icon(
                      icon: _flashIcon(m.flashMode),
                      onPressed: (_busy || m.switching) ? null : _onToggleFlash,
                      tooltip: 'Flash',
                    ),
                    const SizedBox(width: 76),
                    // Only the badge rebuilds while pinching, not the preview.
                    ValueListenableBuilder<double>(
                      valueListenable: m.zoomNotifier,
                      builder: (context, zoom, _) =>
                          _CameraControl.label('${zoom.toStringAsFixed(1)}×'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Shutter row, kept clear of the bottom safe area.
          Positioned.fill(
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _kRowPadX),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CameraControl.icon(
                          icon: Icons.photo_library_outlined,
                          onPressed: _busy ? null : _onPickPressed,
                          tooltip: 'Pick from gallery',
                        ),
                        ShutterButton(
                          onPressed: _onShutter,
                          enabled: !_busy && !m.switching,
                          onPressedChanged: (p) =>
                              setState(() => _shutterPressed = p),
                        ),
                        _CameraControl.icon(
                          icon: Icons.cameraswitch_outlined,
                          onPressed:
                              (_busy || m.switching || !m.canSwitchCamera)
                              ? null
                              : _onFlipCamera,
                          tooltip: 'Switch camera',
                        ),
                      ],
                    ),
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
    final cameraReady =
        _usePicker ||
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
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Press shutter\nto pick a photo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: MachineFrame(slotChild: viewfinder)),
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

/// Icon reflecting the current flash mode.
IconData _flashIcon(FlashMode mode) {
  switch (mode) {
    case FlashMode.always:
    case FlashMode.torch:
      return Icons.flash_on;
    case FlashMode.auto:
      return Icons.flash_auto;
    case FlashMode.off:
      return Icons.flash_off;
  }
}

/// Diameter shared by every round on-screen control (flash, zoom, gallery,
/// flip) so the top and bottom rows line up.
const double _kControlSize = 46;

/// Horizontal inset of the top/bottom control rows, shared so flash lines up
/// over the gallery button and zoom over the flip button.
const double _kRowPadX = 24;

BoxDecoration _controlDecoration() => BoxDecoration(
  shape: BoxShape.circle,
  color: Colors.black.withValues(alpha: 0.4),
  border: Border.all(color: Colors.white24, width: 1),
);

/// A single round, translucent camera control with two variants — similar to a
/// React component that takes a `variant` prop, expressed here with named
/// constructors:
///   • [_CameraControl.icon]  — a tappable icon button (flash / gallery / flip).
///                              Pass a null `onPressed` to render it disabled.
///   • [_CameraControl.label] — a non-interactive text readout (zoom).
class _CameraControl extends StatelessWidget {
  const _CameraControl._({
    required this.child,
    required this.interactive,
    this.onPressed,
    this.tooltip,
  });

  /// Tappable icon button. `onPressed == null` shows it dimmed/disabled.
  factory _CameraControl.icon({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return _CameraControl._(
      interactive: true,
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  /// Static text readout, e.g. the current zoom "1.8×".
  factory _CameraControl.label(String text) {
    return _CameraControl._(
      interactive: false,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  final Widget child;
  final bool interactive;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final disabled = interactive && onPressed == null;
    Widget control = Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Container(
        width: _kControlSize,
        height: _kControlSize,
        alignment: Alignment.center,
        decoration: _controlDecoration(),
        child: child,
      ),
    );

    if (!interactive) return control;

    control = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: control,
    );
    return tooltip == null
        ? control
        : Tooltip(message: tooltip!, child: control);
  }
}
