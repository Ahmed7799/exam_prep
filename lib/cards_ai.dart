import 'dart:convert';

import 'models.dart';
import 'syllabus_ai.dart';

/// Prompt for the Claude app: attach the PDF, paste this, then paste the reply
/// back into the app.
String buildCardsPrompt({
  required String topicName,
  int? fromPage,
  int? toPage,
  String? pageText,
}) {
  final String range;
  if (fromPage != null && toPage != null) {
    range = 'pages $fromPage to $toPage';
  } else if (fromPage != null) {
    range = 'page $fromPage onwards';
  } else {
    range = 'the whole PDF';
  }
  final source = pageText == null
      ? 'I have attached a PDF. Make flashcards from $range (use the page numbers printed on the PDF pages)'
      : 'Below is the text of $range of my study material, with each page marked. Make flashcards from it';
  final tail = pageText == null
      ? ''
      : '\nIf a page refers to a diagram, chart or table that is missing from the text, I may attach that page as an image; use it too.\n\nTEXT:\n$pageText\n';
  return '''
$source for the topic "$topicName" in my exam preparation.

Reply with ONLY one JSON code block and nothing else, in exactly this shape:

{"cards": [
  {"front": "Which article abolishes untouchability?", "back": "**Article 17** abolishes **untouchability** and forbids its practice in any form.", "page": 42}
]}

Rules:
- One fact or idea per card. The front is a clear question or cue; the back is a short, exact answer.
- In the back, put key terms and the relations between them in **double asterisks** so they show in bold. Use ==double equals== for a colour highlight if useful.
- "page" is the page number where the fact appears (the printed page number, as marked). Every card must have it.
- Cover everything in the range that could be asked in the exam: definitions, numbers, dates, lists, causes and effects, comparisons.
- Do not invent facts that are not in the PDF.
- If there are too many cards for one reply, give the first part, ending at a clean point, and tell me which page to continue from. I will ask for the next part.
$tail''';
}

/// Reads Claude's pasted reply: {"cards": [...]} or a bare list of cards.
List<CardDraft> parseClaudeCards(String text) {
  final json = extractJson(text);
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
  Object? list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map) {
    list = decoded['cards'];
  }
  if (list is! List) {
    throw SyllabusAiException('The reply did not contain a "cards" list.');
  }
  final out = <CardDraft>[];
  for (final item in list) {
    if (item is! Map) continue;
    final front = (item['front'] ?? '').toString().trim();
    final back = (item['back'] ?? '').toString().trim();
    if (front.isEmpty || back.isEmpty) continue;
    out.add(CardDraft(front, back, page: _page(item['page'])));
  }
  if (out.isEmpty) {
    throw SyllabusAiException('No cards were found in the reply.');
  }
  return out;
}

int? _page(Object? v) {
  int? p;
  if (v is num) {
    p = v.toInt();
  } else if (v != null) {
    final m = RegExp(r'\d+').firstMatch(v.toString());
    if (m != null) p = int.tryParse(m.group(0)!);
  }
  return (p != null && p > 0) ? p : null;
}
