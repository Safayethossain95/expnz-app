import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's preferred month start day (1–28).
/// e.g. if set to 24, the "this month" period runs from the 24th of last
/// month through the 23rd of the current month.
class MonthStartService {
  static final MonthStartService _instance = MonthStartService._internal();
  factory MonthStartService() => _instance;
  MonthStartService._internal();

  static const String _prefKey = 'expnz_month_start_day_v1';
  static const String _firestoreDoc = 'month_start';

  int _startDay = 1; // default: calendar month
  int get startDay => _startDay;

  // ─── Load ──────────────────────────────────────────────────────────────────

  Future<int> load() async {
    final prefs = await SharedPreferences.getInstance();
    _startDay = prefs.getInt(_prefKey) ?? 1;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc(_firestoreDoc)
            .get();
        if (doc.exists && doc.data() != null) {
          final cloudDay = doc.data()!['startDay'] as int?;
          if (cloudDay != null && cloudDay >= 1 && cloudDay <= 28) {
            _startDay = cloudDay;
            await prefs.setInt(_prefKey, cloudDay);
          }
        }
      }
    } catch (e) {
      debugPrint('MonthStartService load error: $e');
    }

    return _startDay;
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> save(int day) async {
    assert(day >= 1 && day <= 28, 'Month start day must be 1–28');
    _startDay = day;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, day);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc(_firestoreDoc)
            .set({
          'startDay': day,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('MonthStartService save error: $e');
    }
  }

  // ─── Date range helpers ────────────────────────────────────────────────────

  /// Returns the [start, end] DateTime range for the current billing period.
  /// If [startDay] is 1, it's just the current calendar month.
  /// If e.g. startDay = 24 and today is Oct 10, the period is Sep 24 → Oct 23.
  (DateTime start, DateTime end) currentPeriod() {
    final now = DateTime.now();
    return periodContaining(now);
  }

  /// Returns the [start, end] range for the period that contains [date].
  (DateTime start, DateTime end) periodContaining(DateTime date) {
    final day = _startDay;

    DateTime periodStart;
    if (date.day >= day) {
      // We're at or after start-day this month → period started this month
      periodStart = DateTime(date.year, date.month, day);
    } else {
      // We're before start-day this month → period started last month
      final prevMonth = DateTime(date.year, date.month - 1, 1);
      // Clamp to last day of that month to avoid overflow
      final lastDayOfPrev = DateTime(date.year, date.month, 0).day;
      periodStart = DateTime(prevMonth.year, prevMonth.month, day.clamp(1, lastDayOfPrev));
    }

    // End is the day BEFORE the next period's start
    final nextPeriodStart = DateTime(periodStart.year, periodStart.month + 1, day);
    final periodEnd = nextPeriodStart.subtract(const Duration(days: 1));

    return (periodStart, periodEnd);
  }

  /// Returns the current [MonthPeriod] object.
  MonthPeriod currentMonthPeriod() {
    final (start, _) = currentPeriod();
    final nextPeriodStart = DateTime(start.year, start.month + 1, _startDay);
    return MonthPeriod(
      start: start,
      end: nextPeriodStart,
      isCurrent: true,
    );
  }

  /// Generates the current period plus [count] previous periods (default 24 months).
  List<MonthPeriod> generatePeriods({int count = 24}) {
    final current = currentMonthPeriod();
    final periods = <MonthPeriod>[current];

    for (int i = 1; i <= count; i++) {
      final pStart = DateTime(current.start.year, current.start.month - i, _startDay);
      final pEnd = DateTime(pStart.year, pStart.month + 1, _startDay);
      periods.add(MonthPeriod(
        start: pStart,
        end: pEnd,
        isCurrent: false,
      ));
    }

    return periods;
  }

  /// Checks whether [date] falls within the current billing period.
  bool isInCurrentPeriod(DateTime date) {
    return currentMonthPeriod().contains(date);
  }

  /// Human-readable label for the current period, e.g. "15 Oct – 15 Nov 2026"
  String periodLabel() {
    return currentMonthPeriod().label;
  }
}

/// Represents a billing period range, e.g. 15 Oct – 15 Nov 2026.
class MonthPeriod {
  final DateTime start;
  final DateTime end;
  final bool isCurrent;

  const MonthPeriod({
    required this.start,
    required this.end,
    this.isCurrent = false,
  });

  /// Formatted period string, e.g. "15 Oct – 15 Nov 2026"
  String get label {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final sDay = start.day;
    final sMonth = months[start.month - 1];
    final eDay = end.day;
    final eMonth = months[end.month - 1];

    if (start.year == end.year) {
      return '$sDay $sMonth – $eDay $eMonth ${end.year}';
    } else {
      return '$sDay $sMonth ${start.year} – $eDay $eMonth ${end.year}';
    }
  }

  /// Checks if [date] falls within [start, end] (inclusive)
  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthPeriod &&
          runtimeType == other.runtimeType &&
          start.year == other.start.year &&
          start.month == other.start.month &&
          start.day == other.start.day &&
          end.year == other.end.year &&
          end.month == other.end.month &&
          end.day == other.end.day;

  @override
  int get hashCode => Object.hash(start.year, start.month, start.day, end.year, end.month, end.day);
}
