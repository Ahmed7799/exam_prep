/// A run of card text: plain, **bold** or ==highlighted==.
class MarkupPart {
  const MarkupPart(this.text, {this.bold = false, this.highlight = false});

  final String text;
  final bool bold;
  final bool highlight;
}

final RegExp _markup = RegExp(r'\*\*(.+?)\*\*|==(.+?)==', dotAll: true);

/// Splits card text on **bold** and ==highlight== markers.
List<MarkupPart> parseMarkup(String s) {
  final out = <MarkupPart>[];
  var pos = 0;
  for (final m in _markup.allMatches(s)) {
    if (m.start > pos) out.add(MarkupPart(s.substring(pos, m.start)));
    final bold = m.group(1);
    if (bold != null) {
      out.add(MarkupPart(bold, bold: true));
    } else {
      out.add(MarkupPart(m.group(2) ?? '', highlight: true));
    }
    pos = m.end;
  }
  if (pos < s.length) out.add(MarkupPart(s.substring(pos)));
  return out;
}

/// The text without markers, for search and short previews.
String plainText(String s) => parseMarkup(s).map((p) => p.text).join();

String _escapeHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Card text as HTML for Anki: <b> for bold, <mark> for highlight.
String markupToHtml(String s) {
  final b = StringBuffer();
  for (final p in parseMarkup(s)) {
    final t = _escapeHtml(p.text);
    if (p.bold) {
      b.write('<b>$t</b>');
    } else if (p.highlight) {
      b.write('<mark>$t</mark>');
    } else {
      b.write(t);
    }
  }
  return b.toString().replaceAll('\r\n', '\n').replaceAll('\n', '<br>').replaceAll('\t', ' ');
}
