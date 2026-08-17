import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/features/book/stamp_selection.dart';

void main() {
  late StampSelection selection;

  setUp(() => selection = StampSelection());
  tearDown(() => selection.dispose());

  test('nothing is selected to begin with', () {
    expect(selection.state, isEmpty);
  });

  test('entering selects the stamp that was long-pressed', () {
    selection.enter('a');
    expect(selection.state, {'a'});
  });

  test('toggling adds and removes', () {
    selection.enter('a');
    selection.toggle('b');
    expect(selection.state, {'a', 'b'});

    selection.toggle('a');
    expect(selection.state, {'b'});
  });

  test('deselecting the last stamp leaves selection mode', () {
    selection.enter('a');
    selection.toggle('a');

    // An empty set *is* "not selecting" — there is no separate flag that could
    // disagree with it.
    expect(selection.state, isEmpty);
  });

  test('clearing exits selection mode', () {
    selection.enter('a');
    selection.toggle('b');

    selection.clear();

    expect(selection.state, isEmpty);
  });

  test('clearing when nothing is selected does not notify', () {
    var notifications = 0;
    selection.addListener((_) => notifications++);
    // addListener fires once immediately with the current state.
    notifications = 0;

    selection.clear();

    expect(notifications, 0);
  });
}
