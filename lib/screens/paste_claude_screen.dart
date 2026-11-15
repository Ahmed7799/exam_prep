import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../calc.dart';
import '../parser.dart';
import '../syllabus_ai.dart';

/// Import a syllabus that Claude (in the Claude app) has already broken down.
/// Copy the prompt, run it there with your PDF, paste the reply here, review, add.
/// Pops with the number of topics added.
class ClaudeImportScreen extends StatefulWidget {
  const ClaudeImportScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ClaudeImportScreen> createState() => _ClaudeImportScreenState();
}

class _ClaudeImportScreenState extends State<ClaudeImportScreen> {
  final TextEditingController _reply = TextEditingController();
  String? _error;
  List<ParsedTopic>? _items;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: claudePrompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt copied. Paste it into Claude with your PDF.')),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      setState(() => _error = 'The clipboard is empty. Copy Claude\'s reply first.');
      return;
    }
    setState(() {
      _reply.text = text;
      _error = null;
    });
  }

  void _read() {
    try {
      final items = parseClaudeSyllabus(_reply.text);
      setState(() {
        _items = items;
        _error = null;
      });
    } on SyllabusAiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _removeAt(int index) {
    final items = _items;
    if (items == null) return;
    final level = items[index].level;
    var end = index + 1;
    while (end < items.length && items[end].level > level) {
      end++;
    }
    setState(() => items.removeRange(index, end));
  }

  Future<void> _add() async {
    final items = _items;
    if (items == null || items.isEmpty) return;
    final n = await widget.state.importParsed(items);
    if (!mounted) return;
    Navigator.of(context).pop(n);
  }

  Widget _step(BuildContext context, int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 11, child: Text('$number', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _step(context, 1, 'Copy the prompt below.'),
        _step(context, 2, 'Open the Claude app, attach your syllabus PDF and paste the prompt.'),
        _step(context, 3, 'Copy Claude\'s whole reply and come back here.'),
        _step(
          context,
          4,
          'Paste it below and tap Read reply. Long syllabus? Ask Claude for the next part '
          'and import again; each import adds to your syllabus.',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _copyPrompt,
          icon: const Icon(Icons.copy),
          label: const Text('Copy prompt for Claude'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reply,
          minLines: 6,
          maxLines: 10,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Claude\'s reply',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from clipboard'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        FilledButton.icon(
          onPressed: _read,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Read reply'),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items!;
    var hours = 0.0;
    for (var i = 0; i < items.length; i++) {
      final isParent = i + 1 < items.length && items[i + 1].level > items[i].level;
      if (!isParent) hours += items[i].sizeHours;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${items.length} topics, about ${formatHours(hours)} of study. '
              'Remove anything that does not belong. You can edit sizes later.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final t = items[i];
              final isParent = i + 1 < items.length && items[i + 1].level > t.level;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.only(left: 16.0 + t.level * 18, right: 4),
                title: Text(
                  t.name,
                  style: isParent ? const TextStyle(fontWeight: FontWeight.w600) : null,
                ),
                subtitle: isParent ? null : Text(formatHours(t.sizeHours)),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeAt(i),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _items = null),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: items.isEmpty ? null : _add,
                    child: Text('Add ${items.length} topics'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Claude')),
      body: _items == null ? _form(context) : _preview(context),
    );
  }
}
