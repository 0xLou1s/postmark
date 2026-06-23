import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/perforated_border.dart';
import 'machine_controller.dart';
import 'widgets/machine_frame.dart';
import 'widgets/shutter_button.dart';
import '../printing/printing_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(machineControllerProvider).init(),
    );
  }

  Future<void> _onShutter() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await ref.read(machineControllerProvider).capture();
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PrintingScreen(image: bytes)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(machineControllerProvider);
    final cam = m.controller;

    Widget viewfinder;
    if (cam != null && cam.value.isInitialized) {
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () => context.push('/book'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: MachineFrame(slotChild: viewfinder),
            ),
            const Spacer(),
            ShutterButton(
              onPressed: _onShutter,
              enabled: !_busy && cam != null && cam.value.isInitialized,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
