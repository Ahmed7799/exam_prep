import 'markup.dart';
import 'models.dart';

/// Tab-separated text that Anki imports directly (File > Import). Bold and
/// highlights become HTML, the page number goes under the answer, and the
/// topic path becomes a hierarchical tag.
String ankiText(List<Flashcard> cards, {required String Function(int topicId) topicPath}) {
  final b = StringBuffer()
    ..writeln('#separator:tab')
    ..writeln('#html:true')
    ..writeln('#tags column:3');
  for (final c in cards) {
    final back = StringBuffer(markupToHtml(c.back));
    if (c.page != null) back.write('<br><br><small>Page ${c.page}</small>');
    final tags = <String>[
      ankiTag(topicPath(c.topicId)),
      if (c.flag != 0) flagLabel(c.flag).toLowerCase().replaceAll(' ', '_'),
    ].where((t) => t.isNotEmpty).join(' ');
    b.writeln('${markupToHtml(c.front)}\t$back\t$tags');
  }
  return b.toString();
}

/// "Polity > Fundamental Rights" -> "Polity::Fundamental_Rights".
String ankiTag(String path) => path
    .split(' > ')
    .map((p) => p.trim().replaceAll(RegExp(r'[\s"]+'), '_'))
    .where((p) => p.isNotEmpty)
    .join('::');

String _csv(Object? v) {
  final s = v == null ? '' : v.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Every card with its review progress, for a spreadsheet or a backup.
String progressCsv(List<Flashcard> cards, {required String Function(int topicId) topicPath}) {
  final b = StringBuffer()
    ..writeln(
      'front,back,page,topic,flag,status,due,stability,difficulty,reviews,lapses,last_review',
    );
  for (final c in cards) {
    b.writeln([
      c.front,
      c.back,
      c.page,
      topicPath(c.topicId),
      c.flag == 0 ? '' : flagLabel(c.flag),
      c.isNew ? 'new' : 'review',
      c.isNew ? '' : c.due.toIso8601String(),
      c.stability?.toStringAsFixed(3),
      c.difficulty?.toStringAsFixed(3),
      c.reps,
      c.lapses,
      c.lastReview?.toIso8601String(),
    ].map(_csv).join(','));
  }
  return b.toString();
}
