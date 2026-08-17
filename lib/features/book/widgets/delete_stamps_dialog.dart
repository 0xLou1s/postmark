import 'package:flutter/material.dart';

/// Asks before deleting, because deletion is permanent: stamps never enter the
/// shared photo library, so the file in `stamps/` is the only copy in
/// existence.
///
/// Returns true only if the user confirmed — dismissing gives null, which is
/// treated as a cancel.
Future<bool> confirmDeleteStamps(BuildContext context, int count) async {
  final isSingle = count == 1;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isSingle ? 'Delete this stamp?' : 'Delete $count stamps?'),
      content: Text(
        isSingle
            ? 'This is the only copy. Once it goes, it cannot be brought back.'
            : 'These are the only copies. Once they go, they cannot be brought '
                'back.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
