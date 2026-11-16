import 'package:exam_prep/calc.dart';
import 'package:exam_prep/cards_ai.dart';
import 'package:exam_prep/export.dart';
import 'package:exam_prep/fsrs.dart';
import 'package:exam_prep/markup.dart';
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

  group('forecast', () {
    Exam exam(DateTime date, {Set<int> off = const {}, DateTime? start}) => Exam(
          name: 'Test',
          date: date,
          weekdayHours: 2,
          weekendHours: 2,
          daysOff: off,
          startDate: start,
        );

    test('finishes on the day the hours run out', () {
      // Mon 16 to Fri 20 Nov: five study days of 2h.
      final f = buildForecast(
        exam: exam(DateTime(2026, 11, 21)),
        today: DateTime(2026, 11, 16),
        remaining: 7,
      );
      expect(f.studyDays, 5);
      expect(f.totalCapacity, 10);
      expect(f.fits, isTrue);
      expect(f.finish, DateTime(2026, 11, 19)); // 2, 4, 6, 8h by Thursday
      expect(f.needPerDay, 1.4);
    });

    test('reports when it cannot fit', () {
      final f = buildForecast(
        exam: exam(DateTime(2026, 11, 21)),
        today: DateTime(2026, 11, 16),
        remaining: 11,
      );
      expect(f.canFinish, isFalse);
      expect(f.fits, isFalse);
      expect(f.finish, isNull);
      expect(f.shortBy, 1);
    });

    test('keeps revision time free on a long runway', () {
      // 15 study days = 30h; 15% held back leaves 25.5h.
      final today = DateTime(2026, 11, 16);
      final date = DateTime(2026, 12, 1);
      final ok = buildForecast(exam: exam(date), today: today, remaining: 20);
      expect(ok.fits, isTrue);
      final tight = buildForecast(exam: exam(date), today: today, remaining: 27);
      expect(tight.fits, isFalse);
      expect(tight.canFinish, isTrue);
      expect(tight.finish, DateTime(2026, 11, 29)); // 14 days reach 28h
    });

    test('skips rest days', () {
      final f = buildForecast(
        exam: exam(DateTime(2026, 11, 21), off: {2}), // Tuesday off
        today: DateTime(2026, 11, 16),
        remaining: 4,
      );
      expect(f.studyDays, 4);
      expect(f.finish, DateTime(2026, 11, 18)); // Mon + Wed
    });
  });

  group('trailingPace', () {
    Exam exam({Set<int> off = const {}, DateTime? start}) => Exam(
          name: 'Test',
          date: DateTime(2026, 12, 20),
          weekdayHours: 2,
          weekendHours: 2,
          daysOff: off,
          startDate: start,
        );
    final today = DateTime(2026, 11, 16); // Monday

    test('compares logged hours with planned hours since you started', () {
      final pace = trailingPace(
        exam: exam(start: DateTime(2026, 11, 10)),
        today: today,
        loggedByDay: {DateTime(2026, 11, 10): 2, DateTime(2026, 11, 12): 1},
      );
      // 10 to 15 Nov is six days of 2h.
      expect(pace.days, 6);
      expect(pace.planned, 12);
      expect(pace.logged, 3);
      expect(pace.shortfall, 9);
    });

    test('never looks back more than a week', () {
      final pace = trailingPace(
        exam: exam(start: DateTime(2026, 9, 1)),
        today: today,
        loggedByDay: {},
      );
      expect(pace.days, 7); // 9 to 15 Nov
    });

    test('has nothing to judge on the first day', () {
      final pace = trailingPace(
        exam: exam(start: today),
        today: today,
        loggedByDay: {},
      );
      expect(pace.planned, 0);
      expect(pace.shortfall, 0);
    });

    test('does not count rest days', () {
      final pace = trailingPace(
        exam: exam(start: DateTime(2026, 11, 10), off: {7}), // Sunday off
        today: today,
        loggedByDay: {},
      );
      expect(pace.days, 5); // 10 to 14 Nov, 15 Nov is a Sunday
      expect(pace.planned, 10);
    });
  });

  group('alertFor', () {
    test('escalates with days behind', () {
      expect(alertFor(behindHours: 0, dailyHours: 3, fits: true), Alert.onTrack);
      expect(alertFor(behindHours: 2, dailyHours: 3, fits: true), Alert.nudge);
      expect(alertFor(behindHours: 5, dailyHours: 3, fits: true), Alert.warning);
      expect(alertFor(behindHours: 12, dailyHours: 3, fits: true), Alert.alarm);
      expect(alertFor(behindHours: 0, dailyHours: 3, fits: false), Alert.warning);
      expect(alertFor(behindHours: 1, dailyHours: 3, fits: false), Alert.alarm);
    });
  });

  group('papers in the Claude reply', () {
    test('reads the paper on top-level sections only', () {
      final items = topicsFromToolInput({
        'topics': [
          {'name': 'Polity', 'level': 0, 'paper': 1, 'size_hours': 0},
          {'name': 'Rights', 'level': 1, 'paper': 2, 'size_hours': 2},
          {'name': 'Physics', 'level': 0, 'paper': 2, 'size_hours': 2},
          {'name': 'Maths', 'level': 0, 'paper': 9, 'size_hours': 2},
          {'name': 'Law', 'level': 0, 'size_hours': 2},
        ],
      });
      expect(items.map((e) => e.paper).toList(), [1, 0, 2, 0, 0]);
    });
  });

  group('FSRS', () {
    const fsrs = Fsrs();
    final start = DateTime(2026, 11, 13, 9);

    FsrsOutcome first(int rating) => fsrs.review(
          stability: null,
          difficulty: null,
          lastReview: null,
          now: start,
          rating: rating,
        );

    test('new cards: Again in 10 minutes, then 1, 3 and 16 days', () {
      expect(first(1).due, start.add(const Duration(minutes: 10)));
      expect(first(2).due, DateTime(2026, 11, 14));
      expect(first(3).due, DateTime(2026, 11, 16));
      expect(first(4).due, DateTime(2026, 11, 29));
      expect(first(4).difficulty < first(1).difficulty, isTrue);
    });

    test('a card recalled on time gets a longer gap; a lapse a shorter memory', () {
      final f = first(3);
      final now = DateTime(2026, 11, 16, 9);
      FsrsOutcome again(int rating) => fsrs.review(
            stability: f.stability,
            difficulty: f.difficulty,
            lastReview: start,
            now: now,
            rating: rating,
          );
      expect(again(2).due, DateTime(2026, 11, 21));
      expect(again(3).due, DateTime(2026, 11, 27));
      expect(again(4).due, DateTime(2026, 12, 12));
      expect(again(1).stability < f.stability, isTrue);
      expect(again(1).due, now.add(const Duration(minutes: 10)));
    });

    test('never schedules past the cap', () {
      const capped = Fsrs(maxIntervalDays: 5);
      final out = capped.review(
        stability: null,
        difficulty: null,
        lastReview: null,
        now: start,
        rating: 4,
      );
      expect(out.due, DateTime(2026, 11, 18));
    });

    test('interval labels', () {
      final now = DateTime(2026, 11, 16, 9);
      expect(intervalLabel(now.add(const Duration(minutes: 10)), now), '10m');
      expect(intervalLabel(DateTime(2026, 11, 19), now), '3d');
      expect(intervalLabel(DateTime(2027, 1, 15), now), '2.0mo');
    });
  });

  group('markup', () {
    test('splits bold and highlight', () {
      final parts = parseMarkup('The **Preamble** is ==not== enforceable');
      expect(parts.map((p) => p.text).toList(), ['The ', 'Preamble', ' is ', 'not', ' enforceable']);
      expect(parts[1].bold, isTrue);
      expect(parts[3].highlight, isTrue);
      expect(plainText('a **b** c'), 'a b c');
    });

    test('turns into safe HTML for Anki', () {
      expect(markupToHtml('**A** < B\nnext'), '<b>A</b> &lt; B<br>next');
    });
  });

  group('exports', () {
    final cards = [
      Flashcard(id: 1, topicId: 7, front: 'Art. 17?', back: '**Untouchability**', page: 42, flag: 1),
      Flashcard(id: 2, topicId: 7, front: 'Say "hi", ok', back: 'b'),
    ];
    String path(int id) => 'Indian Polity > Fundamental Rights';

    test('Anki text has headers, HTML, page and tags', () {
      final lines = ankiText(cards, topicPath: path).trim().split('\n');
      expect(lines[0], '#separator:tab');
      expect(
        lines[3],
        'Art. 17?\t<b>Untouchability</b><br><br><small>Page 42</small>\t'
        'Indian_Polity::Fundamental_Rights hard',
      );
    });

    test('CSV quotes fields with commas and quotes', () {
      final lines = progressCsv(cards, topicPath: path).trim().split('\n');
      expect(lines.length, 3);
      expect(lines[2].startsWith('"Say ""hi"", ok",b,,'), isTrue);
      expect(lines[1].contains(',Hard,new,'), isTrue);
    });
  });

  group('parseClaudeCards', () {
    test('reads cards with pages in a fenced reply', () {
      final cards = parseClaudeCards('''
Here you go:
```json
{"cards": [
  {"front": "Q1", "back": "**A1**", "page": 12},
  {"front": "Q2", "back": "A2", "page": "p. 13"},
  {"front": "", "back": "skipped"},
  {"front": "Q3", "back": "A3"}
]}
```
''');
      expect(cards.map((c) => c.front).toList(), ['Q1', 'Q2', 'Q3']);
      expect(cards.map((c) => c.page).toList(), [12, 13, null]);
    });

    test('rejects replies without cards', () {
      expect(() => parseClaudeCards('{"cards": []}'), throwsA(isA<SyllabusAiException>()));
      expect(() => parseClaudeCards('nothing'), throwsA(isA<SyllabusAiException>()));
    });
  });

  group('PDF pages', () {
    test('printed and PDF page numbers convert both ways', () {
      final s = Source(examId: 1, title: 'Laxmikanth', filePath: '/x.pdf', pageOffset: 8);
      expect(s.printedPage(50), 42);
      expect(s.pdfPage(42), 50);
    });

    test('the cards prompt can carry page text instead of a PDF', () {
      final withText = buildCardsPrompt(
        topicName: 'Fundamental Rights',
        fromPage: 42,
        toPage: 44,
        pageText: '--- Page 42 ---\nArticle 17 abolishes untouchability.',
      );
      expect(withText.contains('Below is the text of pages 42 to 44'), isTrue);
      expect(withText.contains('Article 17 abolishes untouchability.'), isTrue);
      expect(withText.contains('I have attached a PDF'), isFalse);
      final withPdf = buildCardsPrompt(topicName: 'Fundamental Rights', fromPage: 42, toPage: 44);
      expect(withPdf.contains('I have attached a PDF. Make flashcards from pages 42 to 44'), isTrue);
    });
  });
}

