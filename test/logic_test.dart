import 'package:exam_prep/calc.dart';
import 'package:exam_prep/models.dart';
import 'package:exam_prep/parser.dart';
import 'package:exam_prep/planner.dart';
import 'package:exam_prep/syllabus_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSyllabusText', () {
    test('uses indentation for nesting', () {
      final items = parseSyllabusText(
        'Polity\n  Preamble\n  Fundamental Rights\n    Article 14\nEconomy',
      );
      expect(items.map((e) => e.name).toList(), [
        'Polity',
        'Preamble',
        'Fundamental Rights',
        'Article 14',
        'Economy',
      ]);
      expect(items.map((e) => e.level).toList(), [0, 1, 1, 2, 0]);
    });

    test('strips list markers and skips blank lines', () {
      final items = parseSyllabusText('1. History\n\n- Ancient\n- Medieval\n(a) Modern');
      expect(items.map((e) => e.name).toList(), ['History', 'Ancient', 'Medieval', 'Modern']);
    });

    test('keeps years at the start of a name', () {
      final items = parseSyllabusText('2024 Budget');
      expect(items.single.name, '2024 Budget');
    });

    test('tabs count as indentation', () {
      final items = parseSyllabusText('Science\n\tPhysics\n\t\tOptics');
      expect(items.map((e) => e.level).toList(), [0, 1, 2]);
    });
  });

  group('study hours', () {
    Exam exam({Set<int> off = const {}}) => Exam(
          name: 'Test',
          date: DateTime(2026, 11, 23),
          weekdayHours: 2,
          weekendHours: 4,
          daysOff: off,
        );

    test('counts weekdays and weekends before the exam day', () {
      // Mon 16 Nov to Sun 22 Nov: 5 weekdays x 2h + Sat 4h + Sun 4h.
      expect(availableStudyHours(exam(), DateTime(2026, 11, 16)), 18);
    });

    test('skips rest days', () {
      expect(availableStudyHours(exam(off: {7}), DateTime(2026, 11, 16)), 14);
    });

    test('days until the exam', () {
      expect(daysUntil(exam(), DateTime(2026, 11, 16)), 7);
    });
  });

  group('topicsFromToolInput', () {
    test('repairs level jumps, ranges and tiny leaf sizes', () {
      final items = topicsFromToolInput({
        'topics': [
          {'name': 'Polity', 'level': 0, 'size_hours': 0, 'difficulty': 2, 'importance': 3},
          {'name': 'Rights', 'level': 3, 'size_hours': 0.1, 'difficulty': 9, 'importance': 8},
          {'name': '  ', 'level': 1, 'size_hours': 1, 'difficulty': 1, 'importance': 0},
          {'name': 'Economy', 'level': 0, 'size_hours': 2, 'difficulty': 1, 'importance': 0},
        ],
      });
      expect(items.map((e) => e.name).toList(), ['Polity', 'Rights', 'Economy']);
      expect(items.map((e) => e.level).toList(), [0, 1, 0]);
      expect(items[0].sizeHours, 0); // parent keeps 0
      expect(items[1].sizeHours, 0.5); // tiny leaf raised
      expect(items[1].difficulty, 3);
      expect(items[1].importance, 5);
    });

    test('rejects input with no topics', () {
      expect(() => topicsFromToolInput({'topics': []}), throwsA(isA<SyllabusAiException>()));
      expect(() => topicsFromToolInput(null), throwsA(isA<SyllabusAiException>()));
    });
  });

  group('parseClaudeSyllabus', () {
    const reply = '''
Here is the breakdown:

```json
{"topics": [
  {"name": "Polity", "level": 0, "size_hours": 0, "difficulty": 2, "importance": 3},
  {"name": "Rights", "level": 1, "size_hours": 2, "difficulty": 3, "importance": 4}
]}
```

Let me know if you want the next part.
''';

    test('reads a fenced reply with surrounding text', () {
      final items = parseClaudeSyllabus(reply);
      expect(items.map((e) => e.name).toList(), ['Polity', 'Rights']);
      expect(items[1].sizeHours, 2);
      expect(items[1].difficulty, 3);
    });

    test('accepts a bare list', () {
      final items = parseClaudeSyllabus(
        '[{"name": "Optics", "level": 0, "size_hours": 1, "difficulty": 2, "importance": 0}]',
      );
      expect(items.single.name, 'Optics');
    });

    test('explains when there is no JSON or it is cut off', () {
      expect(() => parseClaudeSyllabus('no json here'), throwsA(isA<SyllabusAiException>()));
      expect(
        () => parseClaudeSyllabus('{"topics": [{"name": "A", "level": 0'),
        throwsA(isA<SyllabusAiException>()),
      );
    });
  });

  test('stage completion', () {
    expect(isComplete(Stage.done), isTrue);
    expect(isComplete(Stage.revision), isTrue);
    expect(isComplete(Stage.reviewing), isFalse);
  });

  group('buildPlan', () {
    Exam exam(DateTime date, {Set<int> off = const {}}) => Exam(
          name: 'Test',
          date: date,
          weekdayHours: 2,
          weekendHours: 2,
          daysOff: off,
        );

    Topic topic(int id, double hours) =>
        Topic(id: id, examId: 1, name: 'T$id', sizeHours: hours);

    test('fills days in order and splits a long topic', () {
      // 5 study days (Mon 16 to Fri 20 Nov), 2h each, exam on Sat 21.
      final plan = buildPlan(
        exam: exam(DateTime(2026, 11, 21)),
        today: DateTime(2026, 11, 16),
        remaining: [topic(1, 3), topic(2, 1), topic(3, 2)],
      );
      expect(plan.fits, isTrue);
      expect(plan.days.length, 5);
      // T1 takes all of day 1 and 1h of day 2, then T2 finishes day 2.
      expect(plan.days[0].items.single.hours, 2);
      expect(plan.days[0].items.single.finishes, isFalse);
      expect(plan.days[1].items.map((i) => i.topic.id).toList(), [1, 2]);
      expect(plan.finishDates[1], DateTime(2026, 11, 17));
      expect(plan.finishDates[2], DateTime(2026, 11, 17));
      expect(plan.finishDates[3], DateTime(2026, 11, 18));
    });

    test('skips rest days', () {
      final plan = buildPlan(
        exam: exam(DateTime(2026, 11, 21), off: {2}), // Tuesday off
        today: DateTime(2026, 11, 16),
        remaining: [topic(1, 4)],
      );
      expect(plan.days.length, 4);
      expect(plan.finishDates[1], DateTime(2026, 11, 18)); // Mon + Wed
    });

    test('reports what does not fit', () {
      final plan = buildPlan(
        exam: exam(DateTime(2026, 11, 18)), // two study days = 4h
        today: DateTime(2026, 11, 16),
        remaining: [topic(1, 3), topic(2, 3)],
      );
      expect(plan.fits, isFalse);
      expect(plan.overflow.map((t) => t.id).toList(), [2]);
      expect(plan.overflowHours, 3);
    });

    test('holds back revision days but uses them if needed', () {
      final date = DateTime(2026, 12, 1);
      final today = DateTime(2026, 11, 16); // 15 study days = 30h
      final easy = buildPlan(exam: exam(date), today: today, remaining: [topic(1, 20)]);
      expect(easy.revisionDaysUsed, isFalse);
      expect(easy.days.where((d) => d.isRevision).length, 2);
      final tight = buildPlan(exam: exam(date), today: today, remaining: [topic(1, 29)]);
      expect(tight.fits, isTrue);
      expect(tight.revisionDaysUsed, isTrue);
    });
  });

  group('alertFor', () {
    test('escalates with days behind', () {
      expect(alertFor(overdueHours: 0, dailyHours: 3, fits: true), Alert.onTrack);
      expect(alertFor(overdueHours: 2, dailyHours: 3, fits: true), Alert.nudge);
      expect(alertFor(overdueHours: 5, dailyHours: 3, fits: true), Alert.warning);
      expect(alertFor(overdueHours: 12, dailyHours: 3, fits: true), Alert.alarm);
      expect(alertFor(overdueHours: 0, dailyHours: 3, fits: false), Alert.warning);
    });
  });
}
