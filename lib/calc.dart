import 'models.dart';

/// Hours you can study from [today] up to (not including) the exam day,
/// using weekday/weekend hours and skipping rest days.
double availableStudyHours(Exam exam, DateTime today) {
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(exam.date.year, exam.date.month, exam.date.day);
  final days = end.difference(start).inDays;
  var hours = 0.0;
  for (var i = 0; i < days; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    if (exam.daysOff.contains(day.weekday)) continue;
    hours += day.weekday >= DateTime.saturday ? exam.weekendHours : exam.weekdayHours;
  }
  return hours;
}

/// Whole days from [today] to the exam date (negative if it has passed).
int daysUntil(Exam exam, DateTime today) {
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(exam.date.year, exam.date.month, exam.date.day);
  return end.difference(start).inDays;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String formatHours(double h) {
  final rounded = (h * 2).round() / 2;
  return rounded == rounded.roundToDouble()
      ? '${rounded.toInt()}h'
      : '${rounded.toStringAsFixed(1)}h';
}
