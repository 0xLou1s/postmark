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
      // iOS / Android: live camera capture
      final bytes = await ref.read(machineControllerProvider).capture();
      if (!mounted) return;
      setState(() => _busy = false);
      if (bytes == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PrintingScreen(image: bytes)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget viewfinder;

    if (_usePicker) {
      // macOS: show a static stamp frame with a "tap to pick" hint
      viewfinder = StampFrame(
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
      );
    } else {
      final m = ref.watch(machineControllerProvider);
      final cam = m.controller;

      if (m.error != null) {
        // No camera (e.g. simulator) — show picker hint instead of error text.
        viewfinder = StampFrame(
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
        );
      } else if (cam != null && cam.value.isInitialized) {
        viewfinder = StampFrame(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cam.value.previewSize!.height,
              height: cam.value.previewSize!.width,
              child: CameraPreview(cam),
            ),
          ),
        );
      } else {
        viewfinder = const Center(child: CircularProgressIndicator());
      }
    }

    final mState = _usePicker ? null : ref.watch(machineControllerProvider);
    final cam = mState?.controller;
    final cameraReady = _usePicker ||
        mState?.error != null ||
        (cam != null && cam.value.isInitialized);

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
