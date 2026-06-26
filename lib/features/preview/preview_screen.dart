import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/perforated_border.dart';
import '../../data/in_memory_stamp_repository.dart';

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

  void _save() {
    ref.read(stampRepositoryProvider.notifier).add(
          image: widget.image,
          caption: _caption.text,
        );
    // Clear the printing/preview stack, land in the book.
    context.go('/book');
  }

  void _retake() => Navigator.of(context).pop(); // back to machine

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
                  height: 320,
                  child: StampFrame(
                    child: Image.memory(widget.image, fit: BoxFit.cover),
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
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: const Text('Save to Book'),
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
