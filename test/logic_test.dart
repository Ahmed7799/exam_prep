import 'package:exam_prep/calc.dart';
import 'package:exam_prep/models.dart';
import 'package:exam_prep/parser.dart';
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
}
