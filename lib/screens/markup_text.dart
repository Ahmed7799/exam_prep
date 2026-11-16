import 'package:flutter/material.dart';

import '../markup.dart';

/// Shows card text with **bold** and ==highlight== applied.
class MarkupText extends StatelessWidget {
  const MarkupText(this.text, {super.key, this.style, this.maxLines, this.textAlign});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final highlight = Colors.amber.withOpacity(0.4);
    return Text.rich(
      TextSpan(
        children: [
          for (final p in parseMarkup(text))
            TextSpan(
              text: p.text,
              style: p.bold
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : (p.highlight ? TextStyle(backgroundColor: highlight) : null),
            ),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}
