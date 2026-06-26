import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/data/in_memory_stamp_repository.dart';

void main() {
  test('starts empty', () {
    final repo = InMemoryStampRepository();
    expect(repo.state, isEmpty);
  });

  test('add inserts a stamp with a generated id and returns it', () {
    final repo = InMemoryStampRepository();
    final s = repo.add(image: Uint8List.fromList([9]), caption: 'hi');
    expect(s.id, isNotEmpty);
    expect(repo.state.length, 1);
    expect(repo.state.single.caption, 'hi');
  });

  test('byId returns the matching stamp or null', () {
    final repo = InMemoryStampRepository();
    final s = repo.add(image: Uint8List(0));
    expect(repo.byId(s.id)?.id, s.id);
    expect(repo.byId('missing'), isNull);
  });
}
