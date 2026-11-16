import 'models.dart';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Study hours you set aside for [day] (0 on a rest day).
double capacityOn(Exam exam, DateTime day) {
  if (exam.daysOff.contains(day.weekday)) return 0;
  final hours = day.weekday >= DateTime.saturday ? exam.weekendHours : exam.weekdayHours;
  return hours < 0 ? 0 : hours;
}

/// Study hours from [from] to [to], both included.
double capacityBetween(Exam exam, DateTime from, DateTime to) {
  var hours = 0.0;
  var day = dayOnly(from);
  final last = dayOnly(to);
  while (!day.isAfter(last)) {
    hours += capacityOn(exam, day);
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return hours;
}

/// Can the remaining syllabus be finished before the exam at your study hours?
class Forecast {
  Forecast({
    required this.remaining,
    required this.totalCapacity,
    required this.usable,
    required this.studyDays,
    required this.finish,
  });

  /// Hours of study still needed.
  final double remaining;

  /// All study hours from today up to the day before the exam.
  final double totalCapacity;

  /// Study hours left after holding back time for revision.
  final double usable;

  /// Days with study hours from today up to the day before the exam.
  final int studyDays;

  /// The day the remaining hours run out at full capacity (null if never).
  final DateTime? finish;

  bool get done => remaining <= 0.0001;

  /// Fits with the revision days still free.
  bool get fits => remaining <= usable + 0.0001;

  /// Fits only by using the revision days.
  bool get canFinish => remaining <= totalCapacity + 0.0001;

  double get shortBy => canFinish ? 0 : remaining - totalCapacity;

  /// Hours per study day needed to finish on time.
  double get needPerDay => studyDays == 0 ? 0 : remaining / studyDays;
}

Forecast buildForecast({
  required Exam exam,
  required DateTime today,
  required double remaining,
  double revisionShare = 0.15,
}) {
  final start = dayOnly(today);
  final end = dayOnly(exam.date);
  final span = end.difference(start).inDays;
  var total = 0.0;
  var days = 0;
  DateTime? finish;
  for (var i = 0; i < span; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    final cap = capacityOn(exam, day);
    if (cap <= 0) continue;
    days++;
    total += cap;
    if (finish == null && remaining > 0.0001 && total + 0.0001 >= remaining) {
      finish = day;
    }
  }
  final usable = days >= 10 ? total * (1 - revisionShare) : total;
  return Forecast(
    remaining: remaining,
    totalCapacity: total,
    usable: usable,
    studyDays: days,
    finish: finish,
  );
}

/// What you planned to study against what you logged over the last week.
class WeekPace {
  WeekPace(this.planned, this.logged, this.days);

  final double planned;
  final double logged;

  /// Study days in the window.
  final int days;

  double get shortfall => planned > logged ? planned - logged : 0;
}

/// Looks at the days from a week ago (or [Exam.startDate], whichever is later)
/// up to yesterday. Today is left out so a morning is not counted as a miss.
WeekPace trailingPace({
  required Exam exam,
  required DateTime today,
  required Map<DateTime, double> loggedByDay,
}) {
  final t = dayOnly(today);
  final weekAgo = DateTime(t.year, t.month, t.day - 7);
  final started = exam.startDate == null ? t : dayOnly(exam.startDate!);
  final from = started.isAfter(weekAgo) ? started : weekAgo;
  final to = DateTime(t.year, t.month, t.day - 1);
  var planned = 0.0;
  var logged = 0.0;
  var days = 0;
  var day = from;
  while (!day.isAfter(to)) {
    final cap = capacityOn(exam, day);
    if (cap > 0) days++;
    planned += cap;
    logged += loggedByDay[day] ?? 0;
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return WeekPace(planned, logged, days);
}

/// How worried the app should be.
enum Alert { onTrack, nudge, warning, alarm }

/// [behindHours] is the shortfall against your own study hours over the last
/// week; [dailyHours] is a typical study day's length; [fits] says whether the
/// syllabus can still be finished before the exam.
Alert alertFor({
  required double behindHours,
  required double dailyHours,
  required bool fits,
}) {
  if (behindHours <= 0.0001) return fits ? Alert.onTrack : Alert.warning;
  final daysBehind = dailyHours <= 0 ? 99.0 : behindHours / dailyHours;
  if (daysBehind > 3 || !fits) return Alert.alarm;
  if (daysBehind > 1) return Alert.warning;
  return Alert.nudge;
}
