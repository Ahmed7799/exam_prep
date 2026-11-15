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
      version: 2,
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
            days_off TEXT NOT NULL DEFAULT ''
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
            due_date TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_topic_exam ON topic(exam_id)');
        await db.execute('CREATE INDEX idx_topic_parent ON topic(parent_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE topic ADD COLUMN due_date TEXT');
        }
      },
    );
  }

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
      await db.insert('exam', exam.toMap());
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

  /// Saves planned finish dates in one go (null clears a topic's date).
  Future<void> setDueDates(Map<int, DateTime?> dates) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final entry in dates.entries) {
        final d = entry.value;
        await txn.update(
          'topic',
          {
            'due_date': d == null
                ? null
                : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          },
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });
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
