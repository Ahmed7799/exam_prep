import 'package:flutter/foundation.dart';

import 'calc.dart';
import 'db.dart';
import 'models.dart';
import 'parser.dart';
import 'planner.dart';

/// Holds the exam and its topic tree, and tells the screens when they change.
class AppState extends ChangeNotifier {
  Exam? exam;
  List<Topic> topics = [];
  Map<int?, List<Topic>> _children = {};

  Plan? _plan;
  DateTime _planDay = DateTime(2000);

  Future<void> load() => _reload();

  Future<void> _reload() async {
    final e = await AppDb.instance.getExam();
    exam = e;
    topics = e == null ? [] : await AppDb.instance.getTopics(e.id!);
    _children = {};
    _plan = null;
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

  double get remainingHours => leaves
      .where((t) => !isComplete(t.stage))
      .fold(0.0, (sum, t) => sum + t.sizeHours);

  // ---- Planner ----

  /// Topics you still have to study, in syllabus order.
  List<Topic> get remainingLeaves {
    final out = <Topic>[];
    void walk(int? parent) {
      for (final t in childrenOf(parent)) {
        if (hasChildren(t)) {
          walk(t.id);
        } else if (!isComplete(t.stage)) {
          out.add(t);
        }
      }
    }

    walk(null);
    return out;
  }

  /// The schedule projected from today with what is left. It is rebuilt
  /// whenever topics change, so it always matches reality.
  Plan get plan {
    final e = exam;
    final today = dayOnly(DateTime.now());
    if (_plan == null || _planDay != today) {
      _planDay = today;
      _plan = e == null
          ? Plan([], {}, [], false)
          : buildPlan(exam: e, today: today, remaining: remainingLeaves);
    }
    return _plan!;
  }

  /// Saves the current projection as the plan you are held to.
  Future<void> replan() async {
    final e = exam;
    if (e == null) return;
    final p = buildPlan(exam: e, today: DateTime.now(), remaining: remainingLeaves);
    final dates = <int, DateTime?>{
      for (final t in topics)
        if (t.id != null) t.id!: p.finishDates[t.id!],
    };
    await AppDb.instance.setDueDates(dates);
    await _reload();
  }

  bool get hasPlan => leaves.any((t) => t.dueDate != null);

  /// Unfinished topics whose planned finish day has passed.
  List<Topic> get overdue {
    final today = dayOnly(DateTime.now());
    return remainingLeaves
        .where((t) => t.dueDate != null && t.dueDate!.isBefore(today))
        .toList();
  }

  double get overdueHours => overdue.fold(0.0, (sum, t) => sum + t.sizeHours);

  /// Topics added or left out since the plan was saved.
  bool get needsReplan => hasPlan && remainingLeaves.any((t) => t.dueDate == null);

  double get typicalDayHours {
    final e = exam;
    if (e == null) return 0;
    return (e.weekdayHours * 5 + e.weekendHours * 2) / 7;
  }

  Alert get alert => alertFor(
        overdueHours: hasPlan ? overdueHours : 0,
        dailyHours: typicalDayHours,
        fits: plan.fits,
      );

  /// Today's slice of the projected plan (empty on a rest day).
  PlanDay? get todayPlan {
    final today = dayOnly(DateTime.now());
    for (final d in plan.days) {
      if (d.date == today) return d;
    }
    return null;
  }
}
