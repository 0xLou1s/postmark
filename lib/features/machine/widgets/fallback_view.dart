import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/perforated_border.dart';
import 'machine_frame.dart';
import 'shutter_button.dart';

/// macOS / desktop / simulator (no live camera): static bezel + pick hint.
class FallbackView extends StatelessWidget {
  const FallbackView({
    super.key,
    required this.ready,
    required this.enabled,
    required this.onShutter,
  });

  /// Whether the viewfinder placeholder can be shown, as opposed to a spinner
  /// while a camera is still initialising.
  final bool ready;
  final bool enabled;
  final VoidCallback onShutter;

  @override
  Widget build(BuildContext context) {
    final Widget viewfinder = ready
        ? StampFrame(
            child: Container(
              color: AppColors.slot,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.hintText,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Press shutter\nto pick a photo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.hintText, fontSize: 13),
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
            ShutterButton(onPressed: onShutter, enabled: enabled),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
