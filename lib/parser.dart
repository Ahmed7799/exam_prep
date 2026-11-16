/// One topic found in a pasted or AI-read syllabus: its name and nesting depth,
/// plus optional estimates (the AI import fills these in).
class ParsedTopic {
  const ParsedTopic(
    this.name,
    this.level, {
    this.sizeHours = 1,
    this.difficulty = 2,
    this.importance = 0,
    this.paper = 0,
  });

  final String name;
  final int level;
  final double sizeHours;
  final int difficulty;
  final int importance;

  /// 1 = General Studies, 2 = Core subject, 0 = not given. Set on level 0 only.
  final int paper;

  ParsedTopic copyWith({double? sizeHours}) => ParsedTopic(
        name,
        level,
        sizeHours: sizeHours ?? this.sizeHours,
        difficulty: difficulty,
        importance: importance,
        paper: paper,
      );
}

// Leading list markers: "- ", "* ", "1. ", "1.2) ", "(a) ", "A. " ...
final RegExp _marker = RegExp(
  r'^(?:[-*•–]+|\(?\d+(?:\.\d+)*[.)]|\(?[A-Za-z][.)])\s+',
);

/// Turns pasted text into a topic list. Nesting comes from indentation:
/// a line indented deeper than the line above becomes its subtopic.
List<ParsedTopic> parseSyllabusText(String text) {
  final result = <ParsedTopic>[];
  final indentStack = <int>[];

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    if (raw.trim().isEmpty) continue;
    final line = raw.replaceAll('\t', '    ');
    final indent = line.length - line.trimLeft().length;
    var name = line.trim();
    name = name.replaceFirst(_marker, '').trim();
    if (name.isEmpty) continue;

    while (indentStack.isNotEmpty && indentStack.last >= indent) {
      indentStack.removeLast();
    }
    final level = indentStack.length;
    indentStack.add(indent);
    result.add(ParsedTopic(name, level));
  }
  return result;
}
