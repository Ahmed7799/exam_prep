import 'package:flutter/foundation.dart';

import 'calc.dart';
import 'db.dart';
import 'fsrs.dart';
import 'models.dart';
import 'parser.dart';
import 'planner.dart';

/// Holds the exam and its topic tree, and tells the screens when they change.
class AppState extends ChangeNotifier {
  Exam? exam;
  List<Topic> topics = [];
  Map<int?, List<Topic>> _children = {};

  List<StudyLog> logs = [];
  List<Flashcard> cards = [];
  int reviewsToday = 0;
  Map<int, Flashcard> _cardById = {};
  Map<int, Topic> _byId = {};
  Map<int, double> _loggedByTopic = {};
  Map<DateTime, double> _loggedByDay = {};

  Future<void> load() => _reload();

  Future<void> _reload() async {
    final e = await AppDb.instance.getExam();
    exam = e;
    topics = e == null ? [] : await AppDb.instance.getTopics(e.id!);
    logs = e == null ? [] : await AppDb.instance.getLogs(e.id!);
    cards = e == null ? [] : await AppDb.instance.getCards(e.id!);
    reviewsToday = e == null ? 0 : await AppDb.instance.countReviewsOn(e.id!, DateTime.now());
    _cardById = {for (final c in cards) c.id!: c};
    _children = {};
    _byId = {for (final t in topics) t.id!: t};
    _loggedByTopic = {};
    _loggedByDay = {};
    for (final l in logs) {
      _loggedByTopic[l.topicId] = (_loggedByTopic[l.topicId] ?? 0) + l.hours;
      final d = dayOnly(l.day);
      _loggedByDay[d] = (_loggedByDay[d] ?? 0) + l.hours;
    }
    for (final t in topics) {
      (_children[t.parentId] ??= []).add(t);
    }
    for (final list in _children.values) {
      list.sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
      });
    }
    notifyListeners();
  }

  // ---- Exam ----

  Future<void> saveExam(Exam e) async {
    await AppDb.instance.saveExam(e);
    await _reload();
  }

  Future<void> deleteExam() async {
    final e = exam;
    if (e == null) return;
    await AppDb.instance.deleteExam(e.id!);
    await _reload();
  }

  // ---- Topic tree ----

  List<Topic> childrenOf(int? parentId) => _children[parentId] ?? const [];

  bool hasChildren(Topic t) => (_children[t.id] ?? const []).isNotEmpty;

  /// Topics with no subtopics: these are the ones you actually study.
  List<Topic> get leaves => topics.where((t) => !hasChildren(t)).toList();

  /// (complete leaf topics, total leaf topics) under [t], or [t] itself if a leaf.
  (int, int) progressOf(Topic t) {
    final kids = childrenOf(t.id);
    if (kids.isEmpty) return (isComplete(t.stage) ? 1 : 0, 1);
    var done = 0;
    var total = 0;
    for (final k in kids) {
      final p = progressOf(k);
      done += p.$1;
      total += p.$2;
    }
    return (done, total);
  }

  int descendantCount(Topic t) {
    var n = 0;
    for (final k in childrenOf(t.id)) {
      n += 1 + descendantCount(k);
    }
    return n;
  }

  Map<Stage, int> get stageCounts {
    final counts = {for (final s in Stage.values) s: 0};
    for (final t in leaves) {
      counts[t.stage] = counts[t.stage]! + 1;
    }
    return counts;
  }

  double get doneFraction {
    final all = leaves;
    if (all.isEmpty) return 0;
    return all.where((t) => isComplete(t.stage)).length / all.length;
  }

  Future<void> addTopic({
    int? parentId,
    required String name,
    double sizeHours = 1,
    int difficulty = 2,
    int importance = 0,
  }) async {
    final e = exam;
    if (e == null) return;
    final siblings = childrenOf(parentId);
    final order = siblings.isEmpty ? 0 : siblings.last.sortOrder + 1;
    await AppDb.instance.insertTopic(Topic(
      examId: e.id!,
      parentId: parentId,
      name: name,
      sizeHours: sizeHours,
      difficulty: difficulty,
      importance: importance,
      sortOrder: order,
    ));
    await _reload();
  }

  Future<void> updateTopic(Topic t) async {
    await AppDb.instance.updateTopic(t);
    await _reload();
  }

  Future<void> setStage(Topic t, Stage stage) async {
    await AppDb.instance.setStage(t.id!, stage);
    await _reload();
  }

  Future<void> deleteTopic(Topic t) async {
    await AppDb.instance.deleteTopic(t.id!);
    await _reload();
  }

  /// Adds a pasted syllabus at the top level. Returns how many topics were added.
  Future<int> importText(String text) => importParsed(parseSyllabusText(text));

  /// Adds already-parsed topics (pasted text or the AI import) at the top level.
  Future<int> importParsed(List<ParsedTopic> items) async {
    final e = exam;
    if (e == null) return 0;
    if (items.isEmpty) return 0;
    final start = topics.isEmpty
        ? 0
        : topics.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await AppDb.instance.insertTopicTree(e.id!, null, items, start);
    await _reload();
    return items.length;
  }

  // ---- Numbers for the Today screen ----

  int get daysLeft => exam == null ? 0 : daysUntil(exam!, DateTime.now());

  double get availableHours =>
      exam == null ? 0 : availableStudyHours(exam!, DateTime.now());

  // ---- Papers and logged hours ----

  /// The paper a topic belongs to: the paper set on its top-level topic.
  int paperOf(Topic t) {
    var cur = t;
    var guard = 0;
    while (cur.parentId != null && guard < 50) {
      final parent = _byId[cur.parentId];
      if (parent == null) break;
      cur = parent;
      guard++;
    }
    return cur.paper;
  }

  /// Names of the topics above [t], like "Polity > Fundamental Rights".
  String pathOf(Topic t) {
    final names = <String>[];
    var cur = t;
    var guard = 0;
    while (cur.parentId != null && guard < 50) {
      final parent = _byId[cur.parentId];
      if (parent == null) break;
      names.insert(0, parent.name);
      cur = parent;
      guard++;
    }
    return names.join(' > ');
  }

  double loggedHoursOf(Topic t) => _loggedByTopic[t.id] ?? 0;

  /// Study time still needed for a topic: its size minus what you logged.
  double remainingOf(Topic t) {
    if (isComplete(t.stage)) return 0;
    final left = t.sizeHours - loggedHoursOf(t);
    return left > 0 ? left : 0;
  }

  /// All topics you study directly, in syllabus order.
  List<Topic> get orderedLeaves {
    final out = <Topic>[];
    void walk(int? parent) {
      for (final t in childrenOf(parent)) {
        if (hasChildren(t)) {
          walk(t.id);
        } else {
          out.add(t);
        }
      }
    }

    walk(null);
    return out;
  }

  List<Topic> get remainingLeaves =>
      orderedLeaves.where((t) => !isComplete(t.stage)).toList();

  double get remainingHours =>
      orderedLeaves.fold(0.0, (sum, t) => sum + remainingOf(t));

  /// Papers that have topics: 1 and 2 first, then 0 (not set) if any topic lacks one.
  List<int> get papers {
    final present = <int>{for (final t in orderedLeaves) paperOf(t)};
    return [for (final p in const [1, 2, 0]) if (present.contains(p)) p];
  }

  bool get hasUntaggedPaper => orderedLeaves.any((t) => paperOf(t) == 0);

  /// Top-level topics, in order (these carry the paper).
  List<Topic> get sections => childrenOf(null);

  Future<void> setPaper(Topic root, int paper) async {
    await AppDb.instance.updateTopic(root.copyWith(paper: paper));
    await _reload();
  }

  PaperStats statsFor(int paper) {
    final today = dayOnly(DateTime.now());
    final weekStart = DateTime(today.year, today.month, today.day - 6);
    var total = 0.0;
    var remaining = 0.0;
    var done = 0;
    var count = 0;
    for (final t in orderedLeaves) {
      if (paperOf(t) != paper) continue;
      count++;
      total += t.sizeHours;
      remaining += remainingOf(t);
      if (isComplete(t.stage)) done++;
    }
    var week = 0.0;
    for (final l in logs) {
      final topic = _byId[l.topicId];
      if (topic == null || paperOf(topic) != paper) continue;
      final d = dayOnly(l.day);
      if (!d.isBefore(weekStart) && !d.isAfter(today)) week += l.hours;
    }
    return PaperStats(paper, count, done, total, remaining, week);
  }

  /// Hours logged on [day], for one paper or (if [paper] is null) all of them.
  double hoursOn(DateTime day, {int? paper}) {
    final d = dayOnly(day);
    var sum = 0.0;
    for (final l in logs) {
      if (dayOnly(l.day) != d) continue;
      if (paper != null) {
        final topic = _byId[l.topicId];
        if (topic == null || paperOf(topic) != paper) continue;
      }
      sum += l.hours;
    }
    return sum;
  }

  List<StudyLog> logsOn(DateTime day) {
    final d = dayOnly(day);
    return logs.where((l) => dayOnly(l.day) == d).toList();
  }

  Topic? topicById(int id) => _byId[id];

  /// Started but not finished topics, most recently studied first.
  List<Topic> get inProgress {
    final lastLog = <int, DateTime>{};
    for (final l in logs) {
      final prev = lastLog[l.topicId];
      if (prev == null || l.day.isAfter(prev)) lastLog[l.topicId] = l.day;
    }
    final started = orderedLeaves.where((t) {
      if (isComplete(t.stage)) return false;
      return loggedHoursOf(t) > 0 ||
          t.stage == Stage.reading ||
          t.stage == Stage.cardsMade ||
          t.stage == Stage.reviewing;
    }).toList();
    started.sort((a, b) {
      final da = lastLog[a.id] ?? DateTime(2000);
      final db = lastLog[b.id] ?? DateTime(2000);
      return db.compareTo(da);
    });
    return started;
  }

  /// Adds [hours] to [t] for today. A topic you had not started moves to Reading.
  Future<void> logStudy(Topic t, double hours) async {
    if (hours <= 0) return;
    await AppDb.instance.addLog(t.id!, dayOnly(DateTime.now()), hours);
    if (t.stage == Stage.notStarted) {
      await AppDb.instance.setStage(t.id!, Stage.reading);
    }
    await _reload();
  }

  Future<void> deleteLog(StudyLog l) async {
    await AppDb.instance.deleteLog(l.id!);
    await _reload();
  }

  // ---- Pace and warnings ----

  double get typicalDayHours {
    final e = exam;
    if (e == null) return 0;
    return (e.weekdayHours * 5 + e.weekendHours * 2) / 7;
  }

  double get todayTarget => exam == null ? 0 : capacityOn(exam!, DateTime.now());

  Forecast get forecast => exam == null
      ? Forecast(remaining: 0, totalCapacity: 0, usable: 0, studyDays: 0, finish: null)
      : buildForecast(exam: exam!, today: DateTime.now(), remaining: remainingHours);

  WeekPace get weekPace => exam == null
      ? WeekPace(0, 0, 0)
      : trailingPace(exam: exam!, today: DateTime.now(), loggedByDay: _loggedByDay);

  Alert get alert => alertFor(
        behindHours: weekPace.shortfall,
        dailyHours: typicalDayHours,
        fits: forecast.canFinish,
      );

  /// The paper that got less of your time this week, if both still have work
  /// left. Both papers carry equal marks, so this is only a nudge.
  int? get suggestedPaper {
    final left = [
      for (final p in papers)
        if (p != 0 && statsFor(p).remainingHours > 0.0001) statsFor(p),
    ];
    if (left.length < 2) return null;
    left.sort((a, b) {
      final c = a.loggedWeek.compareTo(b.loggedWeek);
      return c != 0 ? c : b.remainingHours.compareTo(a.remainingHours);
    });
    if ((left[1].loggedWeek - left[0].loggedWeek).abs() < 0.5) return null;
    return left.first.paper;
  }

  // ---- Flashcards ----

  /// New cards brought into one review session.
  static const newPerSession = 20;

  Flashcard? cardById(int id) => _cardById[id];

  List<Flashcard> cardsOf(int topicId) => cards.where((c) => c.topicId == topicId).toList();

  List<Flashcard> cardsWithFlag(int flag) => cards.where((c) => c.flag == flag).toList();

  /// Reviewed cards whose time has come, oldest first.
  List<Flashcard> get dueCards {
    final now = DateTime.now();
    final list = cards.where((c) => !c.isNew && !c.due.isAfter(now)).toList();
    list.sort((a, b) => a.due.compareTo(b.due));
    return list;
  }

  List<Flashcard> get newCards => cards.where((c) => c.isNew).toList();

  /// What a review session works through: due cards, then some new ones.
  List<Flashcard> get reviewQueue => [...dueCards, ...newCards.take(newPerSession)];

  /// Cards never come back after the exam: intervals stop at the day before it.
  Fsrs get fsrs {
    final d = daysLeft;
    if (exam == null || d < 0) return const Fsrs();
    return Fsrs(maxIntervalDays: d - 1 < 1 ? 1 : d - 1);
  }

  /// When each rating would bring the card back, as short labels.
  Map<int, String> previewLabels(Flashcard c) {
    final now = DateTime.now();
    return {
      for (final r in const [1, 2, 3, 4])
        r: intervalLabel(
          fsrs
              .review(
                stability: c.stability,
                difficulty: c.difficulty,
                lastReview: c.lastReview,
                now: now,
                rating: r,
              )
              .due,
          now,
        ),
    };
  }

  /// Records a review. A topic whose cards you start reviewing moves to Reviewing.
  Future<void> reviewCard(Flashcard c, int rating) async {
    final now = DateTime.now();
    final out = fsrs.review(
      stability: c.stability,
      difficulty: c.difficulty,
      lastReview: c.lastReview,
      now: now,
      rating: rating,
    );
    final updated = c.copyWith(
      due: out.due,
      stability: out.stability,
      difficulty: out.difficulty,
      reps: c.reps + 1,
      lapses: rating == 1 && !c.isNew ? c.lapses + 1 : c.lapses,
      lastReview: now,
    );
    await AppDb.instance.updateCard(updated);
    await AppDb.instance.addReview(c.id!, now, rating);
    final topic = _byId[c.topicId];
    if (topic != null && topic.stage == Stage.cardsMade) {
      await AppDb.instance.setStage(topic.id!, Stage.reviewing);
      await _reload();
      return;
    }
    _putCard(updated);
    reviewsToday++;
    notifyListeners();
  }

  void _putCard(Flashcard c) {
    final i = cards.indexWhere((x) => x.id == c.id);
    if (i >= 0) cards[i] = c;
    _cardById[c.id!] = c;
  }

  Future<void> setCardFlag(Flashcard c, int flag) async {
    final updated = c.copyWith(flag: flag);
    await AppDb.instance.updateCard(updated);
    _putCard(updated);
    notifyListeners();
  }

  Future<void> _markCardsMade(int topicId) async {
    final t = _byId[topicId];
    if (t != null && (t.stage == Stage.notStarted || t.stage == Stage.reading)) {
      await AppDb.instance.setStage(topicId, Stage.cardsMade);
    }
  }

  Future<void> addCard(Flashcard c) async {
    await AppDb.instance.insertCard(c);
    await _markCardsMade(c.topicId);
    await _reload();
  }

  /// Adds cards (for example from a Claude reply) to a topic. Returns the count.
  Future<int> addCards(int topicId, List<CardDraft> drafts) async {
    if (drafts.isEmpty) return 0;
    final now = DateTime.now();
    await AppDb.instance.insertCards([
      for (final d in drafts)
        Flashcard(
          topicId: topicId,
          front: d.front,
          back: d.back,
          page: d.page,
          created: now,
          due: now,
        ),
    ]);
    await _markCardsMade(topicId);
    await _reload();
    return drafts.length;
  }

  Future<void> updateCard(Flashcard c) async {
    await AppDb.instance.updateCard(c);
    await _reload();
  }

  Future<void> deleteCard(Flashcard c) async {
    await AppDb.instance.deleteCard(c.id!);
    await _reload();
  }

  /// Path for tags and exports, like "Polity > Fundamental Rights".
  String topicPathFor(int topicId) {
    final t = _byId[topicId];
    if (t == null) return '';
    final up = pathOf(t);
    return up.isEmpty ? t.name : '$up > ${t.name}';
  }
}

/// Totals for one paper.
class PaperStats {
  PaperStats(
    this.paper,
    this.topicsTotal,
    this.topicsDone,
    this.totalHours,
    this.remainingHours,
    this.loggedWeek,
  );

  final int paper;
  final int topicsTotal;
  final int topicsDone;
  final double totalHours;
  final double remainingHours;

  /// Hours logged in the last 7 days (including today).
  final double loggedWeek;

  /// Share of study hours done, from 0 to 1.
  double get doneFraction {
    if (totalHours <= 0) return 0;
    final f = 1 - remainingHours / totalHours;
    if (f < 0) return 0;
    if (f > 1) return 1;
    return f;
  }
}
