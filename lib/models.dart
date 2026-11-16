import 'package:flutter/material.dart';

/// Where a topic is in your pipeline: read it, make cards, review the cards.
enum Stage { notStarted, reading, cardsMade, reviewing, done, revision }

extension StageInfo on Stage {
  String get label => switch (this) {
        Stage.notStarted => 'Not started',
        Stage.reading => 'Reading',
        Stage.cardsMade => 'Cards made',
        Stage.reviewing => 'Reviewing',
        Stage.done => 'Done',
        Stage.revision => 'Revision',
      };

  Color get color => switch (this) {
        Stage.notStarted => Colors.blueGrey,
        Stage.reading => Colors.blue,
        Stage.cardsMade => Colors.purple,
        Stage.reviewing => Colors.orange,
        Stage.done => Colors.green,
        Stage.revision => Colors.teal,
      };
}

/// A topic counts as complete once its cards are finished (Done or Revision).
bool isComplete(Stage s) => s == Stage.done || s == Stage.revision;

String difficultyLabel(int d) => switch (d) {
      1 => 'Easy',
      3 => 'Hard',
      _ => 'Medium',
    };

class Exam {
  Exam({
    this.id,
    required this.name,
    required this.date,
    required this.weekdayHours,
    required this.weekendHours,
    required this.daysOff,
    this.startDate,
  });

  final int? id;
  final String name;
  final DateTime date;
  final double weekdayHours;
  final double weekendHours;

  /// Weekday numbers that are rest days: 1 = Monday ... 7 = Sunday.
  final Set<int> daysOff;

  /// The day you started tracking; the behind-pace check never looks earlier.
  final DateTime? startDate;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'exam_date': _isoDate(date),
        'weekday_hours': weekdayHours,
        'weekend_hours': weekendHours,
        'days_off': (daysOff.toList()..sort()).join(','),
        if (startDate != null) 'start_date': _isoDate(startDate!),
      };

  factory Exam.fromMap(Map<String, Object?> m) {
    final off = (m['days_off'] as String?) ?? '';
    return Exam(
      id: m['id'] as int?,
      name: m['name'] as String,
      date: DateTime.parse(m['exam_date'] as String),
      weekdayHours: (m['weekday_hours'] as num).toDouble(),
      weekendHours: (m['weekend_hours'] as num).toDouble(),
      daysOff: off.isEmpty ? <int>{} : off.split(',').map(int.parse).toSet(),
      startDate: m['start_date'] == null ? null : DateTime.parse(m['start_date'] as String),
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Topic {
  Topic({
    this.id,
    required this.examId,
    this.parentId,
    required this.name,
    this.sizeHours = 1,
    this.difficulty = 2,
    this.importance = 0,
    this.stage = Stage.notStarted,
    this.sortOrder = 0,
    this.paper = 0,
  });

  final int? id;
  final int examId;
  final int? parentId;
  final String name;

  /// Your estimate of the study time this topic needs, in hours.
  final double sizeHours;

  /// 1 = easy, 2 = medium, 3 = hard.
  final int difficulty;

  /// 0 (low) to 5 (high). Becomes previous-paper weightage later.
  final int importance;
  final Stage stage;
  final int sortOrder;

  /// 1 = General Studies, 2 = Core subject, 0 = not set. Only top-level topics
  /// carry it; subtopics belong to the paper of their top-level topic.
  final int paper;

  Topic copyWith({
    String? name,
    double? sizeHours,
    int? difficulty,
    int? importance,
    Stage? stage,
    int? paper,
  }) =>
      Topic(
        id: id,
        examId: examId,
        parentId: parentId,
        name: name ?? this.name,
        sizeHours: sizeHours ?? this.sizeHours,
        difficulty: difficulty ?? this.difficulty,
        importance: importance ?? this.importance,
        stage: stage ?? this.stage,
        sortOrder: sortOrder,
        paper: paper ?? this.paper,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'exam_id': examId,
        'parent_id': parentId,
        'name': name,
        'size_hours': sizeHours,
        'difficulty': difficulty,
        'weightage': importance,
        'stage': stage.index,
        'sort_order': sortOrder,
        'paper': paper,
      };

  factory Topic.fromMap(Map<String, Object?> m) => Topic(
        id: m['id'] as int?,
        examId: m['exam_id'] as int,
        parentId: m['parent_id'] as int?,
        name: m['name'] as String,
        sizeHours: (m['size_hours'] as num).toDouble(),
        difficulty: m['difficulty'] as int,
        importance: m['weightage'] as int,
        stage: _stageFromIndex(m['stage'] as int),
        sortOrder: m['sort_order'] as int,
        paper: (m['paper'] as int?) ?? 0,
      );
}

Stage _stageFromIndex(int i) =>
    (i < 0 || i >= Stage.values.length) ? Stage.notStarted : Stage.values[i];

String paperName(int paper) => switch (paper) {
      1 => 'Paper 1 · General Studies',
      2 => 'Paper 2 · Core subject',
      _ => 'No paper set',
    };

String paperShort(int paper) => switch (paper) {
      1 => 'Paper 1',
      2 => 'Paper 2',
      _ => 'No paper',
    };

/// Hours you logged on one topic on one day.
class StudyLog {
  StudyLog({this.id, required this.topicId, required this.day, required this.hours});

  final int? id;
  final int topicId;
  final DateTime day;
  final double hours;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'topic_id': topicId,
        'day': _isoDate(day),
        'hours': hours,
      };

  factory StudyLog.fromMap(Map<String, Object?> m) => StudyLog(
        id: m['id'] as int?,
        topicId: m['topic_id'] as int,
        day: DateTime.parse(m['day'] as String),
        hours: (m['hours'] as num).toDouble(),
      );
}
