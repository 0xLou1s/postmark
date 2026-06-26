import 'dart:typed_data';

class Stamp {
  const Stamp({
    required this.id,
    required this.image,
    required this.date,
    this.caption,
  });

  final String id;
  final Uint8List image;
  final DateTime date;
  final String? caption;
}

class MonthGroup {
  const MonthGroup({required this.label, required this.stamps});
  final String label; // e.g. "June 2026"
  final List<Stamp> stamps;
}

const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Groups stamps by (year, month), newest month first, newest day first.
List<MonthGroup> groupByMonth(List<Stamp> stamps) {
  final byKey = <int, List<Stamp>>{};
  for (final s in stamps) {
    final key = s.date.year * 100 + s.date.month;
    byKey.putIfAbsent(key, () => []).add(s);
  }
  final keys = byKey.keys.toList()..sort((a, b) => b.compareTo(a));
  return keys.map((k) {
    final list = byKey[k]!..sort((a, b) => b.date.compareTo(a.date));
    final year = k ~/ 100;
    final month = k % 100;
    return MonthGroup(label: '${_monthNames[month]} $year', stamps: list);
  }).toList();
}
