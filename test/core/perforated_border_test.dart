import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/core/widgets/perforated_border.dart';

void main() {
  test('scallopCount fits whole notches across a side', () {
    // side 100, target radius 10 => diameter 20 => 5 notches
    expect(scallopCount(100, 10), 5);
  });

  test('scallopCount is at least 1', () {
    expect(scallopCount(5, 10), 1);
  });
}
