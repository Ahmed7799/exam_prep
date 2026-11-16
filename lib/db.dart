import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'parser.dart';

/// Local SQLite storage. One exam for now; tables are ready for more later.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'exam_prep.db');
    return openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exam(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            exam_date TEXT NOT NULL,
            weekday_hours REAL NOT NULL,
            weekend_hours REAL NOT NULL,
            days_off TEXT NOT NULL DEFAULT '',
            start_date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE topic(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id INTEGER NOT NULL REFERENCES exam(id) ON DELETE CASCADE,
            parent_id INTEGER REFERENCES topic(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            size_hours REAL NOT NULL DEFAULT 1,
            difficulty INTEGER NOT NULL DEFAULT 2,
            weightage INTEGER NOT NULL DEFAULT 0,
            stage INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            paper INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_topic_exam ON topic(exam_id)');
        await db.execute('CREATE INDEX idx_topic_parent ON topic(parent_id)');
        await _createLogTable(db);
        await _createCardTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE topic ADD COLUMN paper INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE exam ADD COLUMN start_date TEXT');
          await db.update('exam', {'start_date': _iso(DateTime.now())});
          await _createLogTable(db);
        }
        if (oldVersion < 4) {
          await _createCardTables(db);
        }
      },
    );
  }

  static Future<void> _createLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE study_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL REFERENCES topic(id) ON DELETE CASCADE,
        day TEXT NOT NULL,
        hours REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_log_topic ON study_log(topic_id)');
    await db.execute('CREATE INDEX idx_log_day ON study_log(day)');
  }

  static Future<void> _createCardTables(Database db) async {
    await db.execute('''
      CREATE TABLE card(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL REFERENCES topic(id) ON DELETE CASCADE,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        page INTEGER,
        flag INTEGER NOT NULL DEFAULT 0,
        created TEXT NOT NULL,
        due TEXT NOT NULL,
        stability REAL,
        difficulty REAL,
        reps INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        last_review TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_card_topic ON card(topic_id)');
    await db.execute('''
      CREATE TABLE review_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL REFERENCES card(id) ON DELETE CASCADE,
        ts TEXT NOT NULL,
        day TEXT NOT NULL,
        rating INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_review_card ON review_log(card_id)');
    await db.execute('CREATE INDEX idx_review_day ON review_log(day)');
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- Exam ----

  Future<Exam?> getExam() async {
    final db = await _database;
    final rows = await db.query('exam', orderBy: 'id', limit: 1);
    if (rows.isEmpty) return null;
    return Exam.fromMap(rows.first);
  }

  Future<void> saveExam(Exam exam) async {
    final db = await _database;
    if (exam.id == null) {
      final map = exam.toMap();
      map.putIfAbsent('start_date', () => _iso(DateTime.now()));
      await db.insert('exam', map);
    } else {
      await db.update('exam', exam.toMap(), where: 'id = ?', whereArgs: [exam.id]);
    }
  }

  Future<void> deleteExam(int id) async {
    final db = await _database;
    await db.delete('exam', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Topics ----

  Future<List<Topic>> getTopics(int examId) async {
    final db = await _database;
    final rows = await db.query(
      'topic',
      where: 'exam_id = ?',
      whereArgs: [examId],
      orderBy: 'sort_order, id',
    );
    return rows.map(Topic.fromMap).toList();
  }

  Future<int> insertTopic(Topic t) async {
    final db = await _database;
    return db.insert('topic', t.toMap());
  }

  Future<void> updateTopic(Topic t) async {
    final db = await _database;
    await db.update('topic', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> setStage(int id, Stage stage) async {
    final db = await _database;
    await db.update('topic', {'stage': stage.index}, where: 'id = ?', whereArgs: [id]);
  }

  // ---- Cards ----

  Future<List<Flashcard>> getCards(int examId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT c.* FROM card c JOIN topic t ON t.id = c.topic_id '
      'WHERE t.exam_id = ? ORDER BY c.id',
      [examId],
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  Future<int> insertCard(Flashcard c) async {
    final db = await _database;
    return db.insert('card', c.toMap());
  }

  Future<void> insertCards(List<Flashcard> cards) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final c in cards) {
        await txn.insert('card', c.toMap());
      }
    });
  }

  Future<void> updateCard(Flashcard c) async {
    final db = await _database;
    await db.update('card', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCard(int id) async {
    final db = await _database;
    await db.delete('card', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addReview(int cardId, DateTime ts, int rating) async {
    final db = await _database;
    await db.insert('review_log', {
      'card_id': cardId,
      'ts': ts.toIso8601String(),
      'day': _iso(ts),
      'rating': rating,
    });
  }

  Future<int> countReviewsOn(int examId, DateTime day) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM review_log r JOIN card c ON c.id = r.card_id '
      'JOIN topic t ON t.id = c.topic_id WHERE t.exam_id = ? AND r.day = ?',
      [examId, _iso(day)],
    );
    final n = rows.isEmpty ? null : rows.first['n'];
    return n is int ? n : 0;
  }

  // ---- Study log ----

  Future<List<StudyLog>> getLogs(int examId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT l.* FROM study_log l JOIN topic t ON t.id = l.topic_id '
      'WHERE t.exam_id = ? ORDER BY l.day, l.id',
      [examId],
    );
    return rows.map(StudyLog.fromMap).toList();
  }

  Future<void> addLog(int topicId, DateTime day, double hours) async {
    final db = await _database;
    await db.insert('study_log', StudyLog(topicId: topicId, day: day, hours: hours).toMap());
  }

  Future<void> deleteLog(int id) async {
    final db = await _database;
    await db.delete('study_log', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes the topic and, through the foreign key, all its subtopics.
  Future<void> deleteTopic(int id) async {
    final db = await _database;
    await db.delete('topic', where: 'id = ?', whereArgs: [id]);
  }

  /// Inserts a pasted syllabus under [parentId] (null = top level) in one go.
  Future<void> insertTopicTree(
    int examId,
    int? parentId,
    List<ParsedTopic> items,
    int startOrder,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      final stack = <int?>[parentId];
      var order = startOrder;
      for (final item in items) {
        final int level = item.level < stack.length ? item.level : stack.length - 1;
        final id = await txn.insert(
          'topic',
          Topic(
            examId: examId,
            parentId: stack[level],
            name: item.name,
            sizeHours: item.sizeHours,
            difficulty: item.difficulty,
            importance: item.importance,
            paper: stack[level] == null ? item.paper : 0,
            sortOrder: order++,
          ).toMap(),
        );
        stack
          ..removeRange(level + 1, stack.length)
          ..add(id);
      }
    });
  }
}
