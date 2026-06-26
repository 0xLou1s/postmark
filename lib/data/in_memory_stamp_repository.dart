import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../domain/stamp.dart';
import 'stamp_repository.dart';

class InMemoryStampRepository extends StateNotifier<List<Stamp>>
    implements StampRepository {
  InMemoryStampRepository() : super(const []);

  static const _uuid = Uuid();

  @override
  Stamp add({required Uint8List image, String? caption}) {
    final stamp = Stamp(
      id: _uuid.v4(),
      image: image,
      date: DateTime.now(),
      caption: (caption != null && caption.trim().isNotEmpty)
          ? caption.trim()
          : null,
    );
    state = [...state, stamp];
    return stamp;
  }

  @override
  Stamp? byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// The repository as a StateNotifier so widgets rebuild on change.
final stampRepositoryProvider =
    StateNotifierProvider<InMemoryStampRepository, List<Stamp>>(
  (ref) => InMemoryStampRepository(),
);

/// Convenience: stamps grouped by month for the Stamp Book.
final stampGroupsProvider = Provider<List<MonthGroup>>((ref) {
  final stamps = ref.watch(stampRepositoryProvider);
  return groupByMonth(stamps);
});
