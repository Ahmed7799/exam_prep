import 'dart:convert';

import 'parser.dart';

class SyllabusAiException implements Exception {
  SyllabusAiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The prompt you paste into the Claude app together with your syllabus PDF.
const claudePrompt = '''
I have attached the syllabus PDF for an exam I am preparing for. Break it down into a study plan tree.

Reply with ONLY one JSON code block and nothing else, in exactly this shape:

{"topics": [
  {"name": "Indian Polity", "level": 0, "paper": 1, "size_hours": 0, "difficulty": 2, "importance": 3},
  {"name": "Fundamental Rights", "level": 1, "size_hours": 2, "difficulty": 2, "importance": 4}
]}

Rules:
- List topics in the order they appear in the syllabus. "level" is the depth: 0 for a subject or section, 1 for a topic inside it, 2 for a subtopic, and so on. Do not go deeper than level 3.
- Use the syllabus's own wording for names. Do not invent topics that the syllabus does not mention.
- Skip pages that are not syllabus content, such as exam pattern tables, instructions, marks schemes and eligibility, unless they name subjects.
- Topics with nothing nested under them are studied directly. Each should be something I can read and make flashcards from in one sitting. Split a very broad one into smaller topics and merge tiny fragments.
- "paper": only on level 0 items. 1 if the section belongs to Paper 1 (General Studies), 2 if it belongs to Paper 2 (the core subject). Leave it out if the syllabus does not say which paper.
- "size_hours": your rough estimate of study time for a topic with nothing nested under it, usually between 0.5 and 4. Use 0 for topics that have subtopics under them.
- "difficulty": 1 easy, 2 medium, 3 hard.
- "importance": 0 to 5. Use 0 unless the syllabus itself shows weightage, such as marks per section, and then reflect it.
- If the syllabus is too long for one reply, give only the first part, ending at a clean topic boundary, and tell me which part comes next. I will ask for the next part.
''';

/// Reads Claude's pasted answer: a JSON object with a "topics" list (or a bare
/// list), optionally wrapped in a code fence or surrounded by other text.
List<ParsedTopic> parseClaudeSyllabus(String text) {
  final json = _extractJson(text);
  if (json == null) {
    throw SyllabusAiException(
      'Could not find the JSON in what you pasted. Copy Claude\'s whole reply and try again.',
    );
  }
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw SyllabusAiException(
      'The pasted JSON is cut off or has a mistake. Ask Claude to send it again, '
      'or copy the full reply.',
    );
  }
  if (decoded is List) {
    final Map<String, Object?> wrapped = <String, Object?>{'topics': decoded};
    decoded = wrapped;
  }
  return topicsFromToolInput(decoded);
}

String? _extractJson(String text) {
  final trimmed = text.trim();
  final braceAt = trimmed.indexOf('{');
  final bracketAt = trimmed.indexOf('[');
  final bracketFirst = bracketAt != -1 && (braceAt == -1 || bracketAt < braceAt);
  final pairs = bracketFirst
      ? const [('[', ']'), ('{', '}')]
      : const [('{', '}'), ('[', ']')];
  for (final pair in pairs) {
    final start = trimmed.indexOf(pair.$1);
    final end = trimmed.lastIndexOf(pair.$2);
    if (start != -1 && end > start) {
      final candidate = trimmed.substring(start, end + 1);
      try {
        jsonDecode(candidate);
        return candidate;
      } on FormatException {
        // Try the next shape, then fall back to the first candidate below.
      }
    }
  }
  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start != -1 && end > start) return trimmed.substring(start, end + 1);
  return null;
}

/// Turns decoded JSON into topics, repairing small problems: levels that
/// jump more than one step, missing numbers, and empty leaf sizes.
List<ParsedTopic> topicsFromToolInput(Object? input) {
  if (input is! Map || input['topics'] is! List) {
    throw SyllabusAiException('The reply did not contain a "topics" list.');
  }
  final first = <ParsedTopic>[];
  var prevLevel = -1;
  for (final item in input['topics'] as List) {
    if (item is! Map) continue;
    final name = (item['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;

    var level = item['level'] is num ? (item['level'] as num).toInt() : 0;
    if (level < 0) level = 0;
    if (level > prevLevel + 1) level = prevLevel + 1;
    prevLevel = level;

    var size = item['size_hours'] is num ? (item['size_hours'] as num).toDouble() : 1.0;
    if (size < 0) size = 0;
    if (size > 200) size = 200;

    var difficulty = item['difficulty'] is num ? (item['difficulty'] as num).toInt() : 2;
    if (difficulty < 1) difficulty = 1;
    if (difficulty > 3) difficulty = 3;

    var importance = item['importance'] is num ? (item['importance'] as num).toInt() : 0;
    if (importance < 0) importance = 0;
    if (importance > 5) importance = 5;

    var paper = item['paper'] is num ? (item['paper'] as num).toInt() : 0;
    if (paper < 0 || paper > 2) paper = 0;
    if (level != 0) paper = 0;

    first.add(ParsedTopic(
      name,
      level,
      paper: paper,
      sizeHours: size,
      difficulty: difficulty,
      importance: importance,
    ));
  }

  if (first.isEmpty) {
    throw SyllabusAiException('No topics were found in the reply.');
  }

  // A topic with nothing nested under it is studied directly, so it needs a size.
  final fixed = <ParsedTopic>[];
  for (var i = 0; i < first.length; i++) {
    final t = first[i];
    final isParent = i + 1 < first.length && first[i + 1].level > t.level;
    fixed.add(!isParent && t.sizeHours < 0.5 ? t.copyWith(sizeHours: 0.5) : t);
  }
  return fixed;
}
