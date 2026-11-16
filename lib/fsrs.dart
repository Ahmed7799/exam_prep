import 'dart:math' as math;

/// FSRS-5 spaced repetition scheduler.
///
/// Ratings: 1 = Again, 2 = Hard, 3 = Good, 4 = Easy.
/// Intervals are in whole days, except Again, which brings the card back in
/// 10 minutes so you see it again in the same session.
class Fsrs {
  const Fsrs({
    this.retention = 0.9,
    this.maxIntervalDays = 36500,
    this.w = defaultWeights,
  });

  /// Chance of remembering a card when it comes due.
  final double retention;

  /// Longest gap allowed, for example the days left before the exam.
  final int maxIntervalDays;
  final List<double> w;

  static const defaultWeights = <double>[
    0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, //
    0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
  ];

  static const double _decay = -0.5;
  static const double _factor = 19 / 81;

  /// Chance of recall [elapsedDays] after a review with [stability].
  double retrievability(double elapsedDays, double stability) =>
      math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();

  /// Days until recall falls to [retention].
  double intervalFor(double stability) =>
      stability / _factor * (math.pow(retention, 1 / _decay) - 1);

  double _clampD(double d) => d < 1 ? 1 : (d > 10 ? 10 : d);

  double _initialD(int rating) => _clampD(w[4] - math.exp(w[5] * (rating - 1)) + 1);

  double _nextD(double d, int rating) {
    final delta = -w[6] * (rating - 3);
    final damped = d + delta * (10 - d) / 9;
    return _clampD(w[7] * _initialD(4) + (1 - w[7]) * damped);
  }

  double _recallS(double d, double s, double r, int rating) {
    final hard = rating == 2 ? w[15] : 1.0;
    final easy = rating == 4 ? w[16] : 1.0;
    return s *
        (1 +
            math.exp(w[8]) *
                (11 - d) *
                math.pow(s, -w[9]) *
                (math.exp(w[10] * (1 - r)) - 1) *
                hard *
                easy);
  }

  double _forgetS(double d, double s, double r) {
    final next = w[11] *
        math.pow(d, -w[12]) *
        (math.pow(s + 1, w[13]) - 1) *
        math.exp(w[14] * (1 - r));
    return next < s ? next : s;
  }

  /// The card's new memory state and due time after rating it at [now].
  /// Pass null [stability] for a card you have never reviewed.
  FsrsOutcome review({
    required double? stability,
    required double? difficulty,
    required DateTime? lastReview,
    required DateTime now,
    required int rating,
  }) {
    final g = rating < 1 ? 1 : (rating > 4 ? 4 : rating);
    double s;
    double d;
    if (stability == null || difficulty == null || lastReview == null) {
      s = w[g - 1];
      d = _initialD(g);
    } else {
      final elapsed = now.difference(lastReview).inMinutes / 1440;
      d = _nextD(difficulty, g);
      if (elapsed < 1) {
        // Seen again the same day: a small adjustment only.
        s = stability * math.exp(w[17] * (g - 3 + w[18]));
        if (g >= 3 && s < stability) s = stability;
      } else {
        final r = retrievability(elapsed, stability);
        s = g == 1 ? _forgetS(difficulty, stability, r) : _recallS(difficulty, stability, r, g);
      }
    }
    if (s < 0.01) s = 0.01;

    final DateTime due;
    if (g == 1) {
      due = now.add(const Duration(minutes: 10));
    } else {
      var days = intervalFor(s).round();
      if (days < 1) days = 1;
      if (days > maxIntervalDays) days = maxIntervalDays;
      due = DateTime(now.year, now.month, now.day + days);
    }
    return FsrsOutcome(s, d, due);
  }
}

class FsrsOutcome {
  FsrsOutcome(this.stability, this.difficulty, this.due);

  final double stability;
  final double difficulty;
  final DateTime due;
}

/// Short label for when a card comes back: "10m", "3d", "2.5mo", "1.2y".
String intervalLabel(DateTime due, DateTime now) {
  final mins = due.difference(now).inMinutes;
  if (mins < 60) return '${mins < 1 ? 1 : mins}m';
  final days = DateTime(due.year, due.month, due.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days < 1) return '${(mins / 60).round()}h';
  if (days < 30) return '${days}d';
  if (days < 365) return '${(days / 30).toStringAsFixed(1)}mo';
  return '${(days / 365).toStringAsFixed(1)}y';
}
