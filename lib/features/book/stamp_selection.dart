import 'package:flutter_riverpod/legacy.dart';

/// Which stamps are selected in the book, and by extension whether the book is
/// in selection mode at all.
///
/// An empty set means "not selecting". Deriving the mode from the set rather
/// than tracking a separate flag removes the state where the two disagree — a
/// selection mode with nothing in it, or a stray id left over while idle.
class StampSelection extends StateNotifier<Set<String>> {
  StampSelection() : super(const {});

  /// Begins selection with one stamp, discarding anything selected before.
  void enter(String id) => state = {id};

  void toggle(String id) {
    // A fresh set: StateNotifier compares by identity, so mutating [state] in
    // place and reassigning it would change the value without notifying anyone.
    final next = Set<String>.of(state);
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void clear() => state = const {};
}

/// Screen state, not app state: the book resets it on exit, and nothing else
/// reads it.
final stampSelectionProvider =
    StateNotifierProvider<StampSelection, Set<String>>(
  (ref) => StampSelection(),
);
