import 'models.dart';

/// One slice of a topic scheduled on a day.
class PlanItem {
  PlanItem(this.topic, this.hours, this.finishes);

  final Topic topic;
  final double hours;

  /// True when this slice completes the topic.
  final bool finishes;
}

class PlanDay {
  PlanDay(this.date, this.capacity, this.isRevision);

  final DateTime date;
  final double capacity;

  /// Revision days are kept free of new topics unless the syllabus needs them.
  final bool isRevision;
  final List<PlanItem> items = [];

  double get used => items.fold(0.0, (sum, i) => sum + i.hours);
}

class Plan {
  Plan(this.days, this.finishDates, this.overflow, this.revisionDaysUsed);

  final List<PlanDay> days;

  /// Topic id -> day it finishes.
  final Map<int, DateTime> finishDates;

  /// Topics that do not fit before the exam, in order.
  final List<Topic> overflow;

  /// True when new topics had to be pushed into the revision days.
  final bool revisionDaysUsed;

  double get overflowHours => overflow.fold(0.0, (sum, t) => sum + t.sizeHours);

  bool get fits => overflow.isEmpty;

  DateTime? get lastFinish {
    DateTime? last;
    for (final d in finishDates.values) {
      if (last == null || d.isAfter(last)) last = d;
    }
    return last;
  }
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Spreads the [remaining] topics (already in study order) over the days from
/// [today] up to the day before the exam, filling each day to its capacity.
/// The last [revisionShare] of the study days are held back for revision and
/// only used for new topics if the syllabus would not fit otherwise.
Plan buildPlan({
  required Exam exam,
  required DateTime today,
  required List<Topic> remaining,
  double revisionShare = 0.15,
}) {
  final start = dayOnly(today);
  final end = dayOnly(exam.date);
  final span = end.difference(start).inDays;

  final studyDays = <PlanDay>[];
  for (var i = 0; i < span; i++) {
    final date = DateTime(start.year, start.month, start.day + i);
    if (exam.daysOff.contains(date.weekday)) continue;
    final hours =
        date.weekday >= DateTime.saturday ? exam.weekendHours : exam.weekdayHours;
    if (hours <= 0) continue;
    studyDays.add(PlanDay(date, hours, false));
  }

  final revisionCount =
      studyDays.length >= 10 ? (studyDays.length * revisionShare).floor() : 0;
  final learnCount = studyDays.length - revisionCount;
  final days = <PlanDay>[
    for (var i = 0; i < studyDays.length; i++)
      PlanDay(studyDays[i].date, studyDays[i].capacity, i >= learnCount),
  ];

  final finishDates = <int, DateTime>{};
  final overflow = <Topic>[];
  var dayIndex = 0;
  var usedRevision = false;

  for (final topic in remaining) {
    var left = topic.sizeHours <= 0 ? 0.25 : topic.sizeHours;
    while (left > 0.0001 && dayIndex < days.length) {
      final day = days[dayIndex];
      final free = day.capacity - day.used;
      if (free <= 0.0001) {
        dayIndex++;
        continue;
      }
      final take = left < free ? left : free;
      left -= take;
      final finishes = left <= 0.0001;
      day.items.add(PlanItem(topic, take, finishes));
      if (day.isRevision) usedRevision = true;
      if (finishes && topic.id != null) finishDates[topic.id!] = day.date;
    }
    if (left > 0.0001) overflow.add(topic);
  }

  return Plan(days, finishDates, overflow, usedRevision);
}

/// How worried the app should be, from how far behind the plan you are.
enum Alert { onTrack, nudge, warning, alarm }

/// [overdueHours] is the size of unfinished topics whose due date has passed;
/// [dailyHours] is a typical study day's length.
Alert alertFor({
  required double overdueHours,
  required double dailyHours,
  required bool fits,
}) {
  if (overdueHours <= 0.0001) return fits ? Alert.onTrack : Alert.warning;
  final daysBehind = dailyHours <= 0 ? 99.0 : overdueHours / dailyHours;
  if (daysBehind > 3 || !fits) return Alert.alarm;
  if (daysBehind > 1) return Alert.warning;
  return Alert.nudge;
}
