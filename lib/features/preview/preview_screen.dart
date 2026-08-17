import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/perforated_border.dart';
import '../../data/stamp_repository.dart';
import '../../domain/stamp.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, required this.image});
  final Uint8List image;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(stampRepositoryProvider.notifier).add(
            image: widget.image,
            caption: _caption.text,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Stays on the preview, so the bytes are still in hand for a retry.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save that stamp. Try again.")),
      );
      return;
    }
    if (!mounted) return;
    // Off the Stamp branch's stack before switching: go() alone would leave this
    // screen on it, so returning to Stamp would show the preview, not the camera.
    Navigator.of(context).pop();
    context.go('/book');
  }

  void _retake() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  width: 240,
                  child: AspectRatio(
                    aspectRatio: kStampAspectRatio,
                    child: StampFrame(
                      child: Image.memory(widget.image, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Caption',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 16)),
                  Text('Optional', style: TextStyle(color: Colors.black45)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('A few words to keep the moment with the stamp.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              TextField(
                controller: _caption,
                decoration: const InputDecoration(
                  hintText: 'What do you see?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _retake,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save to Book'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
