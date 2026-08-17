import 'package:intl/intl.dart';

/// The machine frame's window opening (463 x 500 px). Viewfinder and printed
/// stamp share it, so what you frame is what you print.
const double kStampAspectRatio = 463 / 500;

class Stamp {
  const Stamp({
    required this.id,
    required this.imagePath,
    required this.date,
    this.caption,
  });

  final String id;

  /// Absolute path to the JPEG. Stored relative in SQLite; see [StampPaths].
  final String imagePath;

  final DateTime date;
  final String? caption;
}

class MonthGroup {
  const MonthGroup({required this.label, required this.stamps});
  final String label;
  final List<Stamp> stamps;
}

/// Every date the user sees: "June 2026" over a month, "Jun 24, 2026" under a
/// stamp.
abstract final class StampDateFormat {
  static final _monthYear = DateFormat.yMMMM();
  static final _dayInFull = DateFormat.yMMMd();

  static String monthYear(DateTime date) => _monthYear.format(date);
  static String dayInFull(DateTime date) => _dayInFull.format(date);
}

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
    return MonthGroup(
      label: StampDateFormat.monthYear(list.first.date),
      stamps: list,
    );
  }).toList();
}
