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
    this.sourceId,
    this.sourcePage,
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

  /// The PDF you read this topic from, and the PDF page you were last on.
  final int? sourceId;
  final int? sourcePage;

  Topic copyWith({
    String? name,
    double? sizeHours,
    int? difficulty,
    int? importance,
    Stage? stage,
    int? paper,
    int? sourceId,
    int? sourcePage,
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
        sourceId: sourceId ?? this.sourceId,
        sourcePage: sourcePage ?? this.sourcePage,
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
        'source_id': sourceId,
        'source_page': sourcePage,
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
        sourceId: m['source_id'] as int?,
        sourcePage: m['source_page'] as int?,
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

/// Revision-list tags you put on cards during review.
const cardFlags = [1, 2, 3];

String flagLabel(int flag) => switch (flag) {
      1 => 'Hard',
      2 => 'Medium',
      3 => 'To review',
      _ => 'None',
    };

Color flagColor(int flag) => switch (flag) {
      1 => Colors.red,
      2 => Colors.orange,
      3 => Colors.blue,
      _ => Colors.grey,
    };

/// A card before it is saved, for example from a Claude reply.
class CardDraft {
  const CardDraft(this.front, this.back, {this.page});

  CardDraft withPage(int? p) => CardDraft(front, back, page: p);

  final String front;
  final String back;

  /// Page number printed on the source PDF.
  final int? page;
}

class Flashcard {
  Flashcard({
    this.id,
    required this.topicId,
    required this.front,
    required this.back,
    this.page,
    this.flag = 0,
    DateTime? created,
    DateTime? due,
    this.stability,
    this.difficulty,
    this.reps = 0,
    this.lapses = 0,
    this.lastReview,
    this.sourceId,
  })  : created = created ?? DateTime.now(),
        due = due ?? DateTime.now();

  final int? id;
  final int topicId;
  final String front;
  final String back;

  /// Page number printed on the source PDF, so you can check the original.
  final int? page;

  /// 0 none, 1 Hard, 2 Medium, 3 To review.
  final int flag;
  final DateTime created;
  final DateTime due;
  final double? stability;
  final double? difficulty;
  final int reps;
  final int lapses;
  final DateTime? lastReview;

  /// The PDF the card was made from, so its page can be opened.
  final int? sourceId;

  bool get isNew => reps == 0;

  Flashcard copyWith({
    int? topicId,
    String? front,
    String? back,
    int? page,
    bool clearPage = false,
    int? flag,
    DateTime? due,
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
    DateTime? lastReview,
    int? sourceId,
  }) =>
      Flashcard(
        id: id,
        topicId: topicId ?? this.topicId,
        front: front ?? this.front,
        back: back ?? this.back,
        page: clearPage ? null : (page ?? this.page),
        flag: flag ?? this.flag,
        created: created,
        due: due ?? this.due,
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        lastReview: lastReview ?? this.lastReview,
        sourceId: sourceId ?? this.sourceId,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'topic_id': topicId,
        'front': front,
        'back': back,
        'page': page,
        'flag': flag,
        'created': created.toIso8601String(),
        'due': due.toIso8601String(),
        'stability': stability,
        'difficulty': difficulty,
        'reps': reps,
        'lapses': lapses,
        'last_review': lastReview?.toIso8601String(),
        'source_id': sourceId,
      };

  factory Flashcard.fromMap(Map<String, Object?> m) => Flashcard(
        id: m['id'] as int?,
        topicId: m['topic_id'] as int,
        front: m['front'] as String,
        back: m['back'] as String,
        page: m['page'] as int?,
        flag: (m['flag'] as int?) ?? 0,
        created: DateTime.parse(m['created'] as String),
        due: DateTime.parse(m['due'] as String),
        stability: (m['stability'] as num?)?.toDouble(),
        difficulty: (m['difficulty'] as num?)?.toDouble(),
        reps: (m['reps'] as int?) ?? 0,
        lapses: (m['lapses'] as int?) ?? 0,
        lastReview: m['last_review'] == null ? null : DateTime.parse(m['last_review'] as String),
        sourceId: m['source_id'] as int?,
      );
}

/// A PDF you read from, kept inside the app.
class Source {
  Source({
    this.id,
    required this.examId,
    required this.title,
    required this.filePath,
    this.pageOffset = 0,
    this.lastPage = 1,
    this.lastTopicId,
  });

  final int? id;
  final int examId;
  final String title;
  final String filePath;

  /// PDF page index minus the page number printed on it. A book whose
  /// printed page 1 is the PDF's 9th page has an offset of 8.
  final int pageOffset;

  /// PDF page index (from 1) where you stopped.
  final int lastPage;
  final int? lastTopicId;

  int printedPage(int pdfPage) => pdfPage - pageOffset;

  int pdfPage(int printed) => printed + pageOffset;

  Source copyWith({String? title, int? pageOffset, int? lastPage, int? lastTopicId}) => Source(
        id: id,
        examId: examId,
        title: title ?? this.title,
        filePath: filePath,
        pageOffset: pageOffset ?? this.pageOffset,
        lastPage: lastPage ?? this.lastPage,
        lastTopicId: lastTopicId ?? this.lastTopicId,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'exam_id': examId,
        'title': title,
        'file_path': filePath,
        'page_offset': pageOffset,
        'last_page': lastPage,
        'last_topic_id': lastTopicId,
      };

  factory Source.fromMap(Map<String, Object?> m) => Source(
        id: m['id'] as int?,
        examId: m['exam_id'] as int,
        title: m['title'] as String,
        filePath: m['file_path'] as String,
        pageOffset: (m['page_offset'] as int?) ?? 0,
        lastPage: (m['last_page'] as int?) ?? 1,
        lastTopicId: m['last_topic_id'] as int?,
      );
}
