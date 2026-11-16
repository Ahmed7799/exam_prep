import 'models.dart';

/// Reads a deck exported from Anki as "Notes in Plain Text" (.txt): one note
/// per line, fields separated by tabs, lines starting with # are headers.
/// The first field is the front, the second the back. Bold and highlights
/// become **bold** and ==highlight==; a "Page 42" in the answer becomes the
/// card's page number.
List<CardDraft> parseAnkiText(String text) {
  var separator = '\t';
  var htmlOn = true;
  final out = <CardDraft>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      final m = RegExp(r'^#separator:(\w+)', caseSensitive: false).firstMatch(line);
      if (m != null) {
        separator = switch (m.group(1)!.toLowerCase()) {
          'comma' => ',',
          'semicolon' => ';',
          'pipe' => '|',
          'space' => ' ',
          _ => '\t',
        };
      }
      if (line.toLowerCase().startsWith('#html:false')) htmlOn = false;
      continue;
    }
    final fields = _split(line, separator);
    if (fields.length < 2) continue;
    final front = htmlOn ? htmlToMarkup(fields[0]) : fields[0].trim();
    var back = htmlOn ? htmlToMarkup(fields[1]) : fields[1].trim();
    int? page;
    final pm = RegExp(r'\n*\s*(?:Page|p\.)\s*(\d+)\s*$', caseSensitive: false).firstMatch(back);
    if (pm != null) {
      page = int.tryParse(pm.group(1)!);
      back = back.substring(0, pm.start).trim();
    }
    if (front.isEmpty || back.isEmpty) continue;
    out.add(CardDraft(front, back, page: page));
  }
  return out;
}

/// Splits one line, honouring "quoted fields" as Anki writes them.
List<String> _split(String line, String sep) {
  final out = <String>[];
  final b = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else if (quoted || b.isEmpty) {
        quoted = !quoted;
      } else {
        b.write(ch);
      }
    } else if (ch == sep && !quoted) {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(ch);
    }
  }
  out.add(b.toString());
  return out;
}

/// Anki field HTML to the app's card text.
String htmlToMarkup(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</(div|p|li)>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ');
  s = s.replaceAllMapped(
    RegExp(r'<(b|strong)(\s[^>]*)?>(.*?)</\1>', caseSensitive: false, dotAll: true),
    (m) => '**${m.group(3)}**',
  );
  s = s.replaceAllMapped(
    RegExp(r'<mark(\s[^>]*)?>(.*?)</mark>', caseSensitive: false, dotAll: true),
    (m) => '==${m.group(2)}==',
  );
  s = s.replaceAllMapped(
    RegExp(r'<span[^>]*background-color[^>]*>(.*?)</span>', caseSensitive: false, dotAll: true),
    (m) => '==${m.group(1)}==',
  );
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
  s = s.replaceAll('****', '').replaceAll('====', '');
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}
