import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/domain/stamp.dart';

void main() {
  test('Stamp holds image, date, optional caption', () {
    final img = Uint8List.fromList([1, 2, 3]);
    final s = Stamp(
      id: 'a1',
      image: img,
      date: DateTime(2026, 6, 24),
      caption: 'sunset',
    );
    expect(s.id, 'a1');
    expect(s.image, img);
    expect(s.date, DateTime(2026, 6, 24));
    expect(s.caption, 'sunset');
  });

  test('caption is optional', () {
    final s = Stamp(
      id: 'a2',
      image: Uint8List(0),
      date: DateTime(2026, 5, 1),
    );
    expect(s.caption, isNull);
  });

  test('groupByMonth groups and sorts newest month first', () {
    Stamp at(int y, int m, int d) => Stamp(
          id: '$y-$m-$d',
          image: Uint8List(0),
          date: DateTime(y, m, d),
        );
    final stamps = [at(2026, 5, 2), at(2026, 6, 10), at(2026, 6, 1)];
    final groups = groupByMonth(stamps);

    expect(groups.length, 2);
    expect(groups.first.label, 'June 2026');
    expect(groups.first.stamps.length, 2);
    expect(groups.first.stamps.first.date.day, 10);
    expect(groups.last.label, 'May 2026');
  });
}
