import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../cards_ai.dart';
import '../models.dart';
import '../syllabus_ai.dart';
import 'markup_text.dart';

/// Make cards with Claude in the Claude app: choose the topic and pages, copy
/// the prompt, run it there with the PDF, paste the reply back here.
class CardsImportScreen extends StatefulWidget {
  const CardsImportScreen({
    super.key,
    required this.state,
    this.topicId,
    this.fromPage,
    this.toPage,
    this.pageText,
    this.sourceId,
  });

  final AppState state;
  final int? topicId;

  /// Printed page numbers of the range, when coming from the PDF reader.
  final int? fromPage;
  final int? toPage;

  /// Text of those pages, read from the PDF, so Claude does not need the file.
  final String? pageText;
  final int? sourceId;

  @override
  State<CardsImportScreen> createState() => _CardsImportScreenState();
}

class _CardsImportScreenState extends State<CardsImportScreen> {
  late int? _topicId = widget.topicId;
  late final _from = TextEditingController(text: widget.fromPage?.toString() ?? '');
  late final _to = TextEditingController(text: widget.toPage?.toString() ?? '');
  late bool _includeText = widget.pageText != null;
  final _reply = TextEditingController();
  List<CardDraft>? _drafts;
  String? _error;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    final topic = _topicId == null ? null : widget.state.topicById(_topicId!);
    if (topic == null) {
      setState(() => _error = 'Choose the topic first.');
      return;
    }
    final prompt = buildCardsPrompt(
      topicName: topic.name,
      fromPage: int.tryParse(_from.text.trim()),
      toPage: int.tryParse(_to.text.trim()),
      pageText: _includeText ? widget.pageText : null,
    );
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _includeText
              ? 'Prompt with the page text copied. Paste it into Claude.'
              : 'Prompt copied. Paste it into Claude with your PDF.',
        ),
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    _reply.text = text;
    _read();
  }

  void _read() {
    try {
      final drafts = parseClaudeCards(_reply.text);
      setState(() {
        _drafts = drafts;
        _error = null;
      });
    } on SyllabusAiException catch (e) {
      setState(() {
        _drafts = null;
        _error = e.message;
      });
    }
  }

  Future<void> _add() async {
    final drafts = _drafts;
    if (drafts == null || drafts.isEmpty) return;
    if (_topicId == null) {
      setState(() => _error = 'Choose the topic first.');
      return;
    }
    final n = await widget.state.addCards(_topicId!, drafts, sourceId: widget.sourceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $n cards')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final leaves = state.orderedLeaves;
    final theme = Theme.of(context);
    final drafts = _drafts;
    final missingPages = drafts?.where((d) => d.page == null).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Cards from Claude')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('1. Choose the topic and pages', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: leaves.any((t) => t.id == _topicId) ? _topicId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Topic', border: OutlineInputBorder()),
            items: [
              for (final t in leaves)
                DropdownMenuItem<int>(
                  value: t.id,
                  child: Text(state.topicPathFor(t.id!), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _topicId = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _from,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'From page',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _to,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'To page',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('2. Run it in the Claude app', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (widget.pageText != null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeText,
              onChanged: (v) => setState(() => _includeText = v),
              title: const Text('Put the page text in the prompt'),
              subtitle: Text(
                _includeText
                    ? 'No need to attach the PDF. For pages with diagrams or tables as images, '
                        'attach screenshots of those pages too.'
                    : 'Attach the PDF in Claude yourself.',
              ),
            ),
            Text(
              '${widget.pageText!.length} characters read from the pages.',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            const Text('Copy the prompt, open Claude, attach the PDF and paste the prompt.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _copyPrompt,
            icon: const Icon(Icons.copy),
            label: const Text('Copy prompt'),
          ),
          const SizedBox(height: 16),
          Text('3. Paste Claude\'s reply', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _reply,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste the reply here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _read, child: const Text('Read reply')),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (drafts != null) ...[
            const SizedBox(height: 16),
            Text('${drafts.length} cards found', style: theme.textTheme.titleSmall),
            if (missingPages > 0)
              Text(
                '$missingPages cards have no page number. You can add it when editing.',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text('Add ${drafts.length} cards'),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < drafts.length; i++)
              Card(
                child: ListTile(
                  title: MarkupText(drafts[i].front),
                  subtitle: MarkupText(
                    '${drafts[i].back}${drafts[i].page == null ? '' : '  (p. ${drafts[i].page})'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Leave out',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      final list = [...drafts]..removeAt(i);
                      _drafts = list;
                    }),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
