import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'markup_text.dart';
import 'topic_picker.dart';

/// Create or edit one card.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, required this.state, this.card, this.topicId});

  final AppState state;
  final Flashcard? card;

  /// Topic to preselect for a new card.
  final int? topicId;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  late final TextEditingController _front = TextEditingController(text: widget.card?.front ?? '');
  late final TextEditingController _back = TextEditingController(text: widget.card?.back ?? '');
  late final TextEditingController _page =
      TextEditingController(text: widget.card?.page?.toString() ?? '');
  late int? _topicId = widget.card?.topicId ?? widget.topicId;
  late int _flag = widget.card?.flag ?? 0;
  String? _error;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _page.dispose();
    super.dispose();
  }

  /// Wraps the selected text in [marker], or inserts a pair at the cursor.
  void _wrap(TextEditingController c, String marker) {
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final chosen = text.substring(start, end);
    final replaced = text.replaceRange(start, end, '$marker$chosen$marker');
    final cursor = chosen.isEmpty ? start + marker.length : end + 2 * marker.length;
    c.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: cursor),
    );
    setState(() {});
  }

  Future<void> _save() async {
    final front = _front.text.trim();
    final back = _back.text.trim();
    final pageText = _page.text.trim();
    final page = pageText.isEmpty ? null : int.tryParse(pageText);
    if (_topicId == null) {
      setState(() => _error = 'Choose the topic this card belongs to.');
      return;
    }
    if (front.isEmpty || back.isEmpty) {
      setState(() => _error = 'Write both the question and the answer.');
      return;
    }
    if (pageText.isNotEmpty && (page == null || page <= 0)) {
      setState(() => _error = 'The page must be a number, like 42.');
      return;
    }
    final existing = widget.card;
    if (existing == null) {
      await widget.state.addCard(Flashcard(
        topicId: _topicId!,
        front: front,
        back: back,
        page: page,
        flag: _flag,
      ));
    } else {
      await widget.state.updateCard(existing.copyWith(
        topicId: _topicId,
        front: front,
        back: back,
        page: page,
        clearPage: page == null,
        flag: _flag,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final card = widget.card;
    if (card == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this card?'),
        content: const Text('Its review history goes with it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.state.deleteCard(card);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _toolbar(TextEditingController c) => Row(
        children: [
          TextButton.icon(
            onPressed: () => _wrap(c, '**'),
            icon: const Icon(Icons.format_bold, size: 18),
            label: const Text('Bold'),
          ),
          TextButton.icon(
            onPressed: () => _wrap(c, '=='),
            icon: const Icon(Icons.highlight, size: 18),
            label: const Text('Highlight'),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final leaves = state.orderedLeaves;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? 'New card' : 'Edit card'),
        actions: [
          if (widget.card != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: leaves.isEmpty
          ? const Center(child: Text('Add syllabus topics first. Every card belongs to one.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TopicField(
                  state: state,
                  topicId: _topicId,
                  onChanged: (id) => setState(() => _topicId = id),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _front,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Question (front)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                _toolbar(_front),
                TextField(
                  controller: _back,
                  minLines: 3,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Answer (back)',
                    helperText: 'Select key terms and tap Bold or Highlight.',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                _toolbar(_back),
                TextField(
                  controller: _page,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Page in the PDF',
                    helperText: 'The page number printed on the source page.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Revision list', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in [0, ...cardFlags])
                      ChoiceChip(
                        label: Text(flagLabel(f)),
                        selected: _flag == f,
                        onSelected: (_) => setState(() => _flag = f),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                if (_front.text.trim().isNotEmpty || _back.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Preview', style: theme.textTheme.titleSmall),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkupText(_front.text, style: theme.textTheme.titleMedium),
                          const Divider(),
                          MarkupText(_back.text),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
