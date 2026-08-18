import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/domain/stamp.dart';

void main() {
  test('Stamp holds imagePath, date, optional caption', () {
    final s = Stamp(
      id: 'a1',
      imagePath: '/tmp/stamps/a1.jpg',
      date: DateTime(2026, 6, 24),
      caption: 'sunset',
    );
    expect(s.id, 'a1');
    expect(s.imagePath, '/tmp/stamps/a1.jpg');
    expect(s.date, DateTime(2026, 6, 24));
    expect(s.caption, 'sunset');
  });

  test('caption is optional', () {
    final s = Stamp(
      id: 'a2',
      imagePath: '/tmp/stamps/a2.jpg',
      date: DateTime(2026, 5, 1),
    );
    expect(s.caption, isNull);
  });

  test('groupByMonth groups and sorts newest month first', () {
    Stamp at(int y, int m, int d) => Stamp(
          id: '$y-$m-$d',
          imagePath: '/tmp/stamps/$y-$m-$d.jpg',
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

  test('a month with no stamps left has no group', () {
    final june = Stamp(
      id: 'a',
      imagePath: '/fake/a.jpg',
      date: DateTime(2026, 6, 10),
    );
    final july = Stamp(
      id: 'b',
      imagePath: '/fake/b.jpg',
      date: DateTime(2026, 7, 4),
    );

    // Deleting June's only stamp must take its header with it, not leave an
    // empty section in the book.
    final groups = groupByMonth([july]);

    expect(groupByMonth([june, july]), hasLength(2));
    expect(groups, hasLength(1));
    expect(groups.single.label, StampDateFormat.monthYear(july.date));
  });
}
