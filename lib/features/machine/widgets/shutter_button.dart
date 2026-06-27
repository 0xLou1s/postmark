import 'package:flutter/material.dart';

class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.onPressedChanged,
  });

  final VoidCallback onPressed;
  final bool enabled;

  /// Fires `true` on touch-down and `false` on release/cancel so the caller can
  /// react (e.g. press the machine frame down).
  final ValueChanged<bool>? onPressedChanged;

  void _setPressed(bool value) => onPressedChanged?.call(value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.black26, width: 4),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8),
            ],
          ),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
