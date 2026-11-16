import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'card_editor_screen.dart';
import 'markup_text.dart';

/// Works through a list of cards.
///
/// With [scheduled] true, your rating updates the spaced-repetition schedule.
/// With false (revision lists), nothing is rescheduled: cards you still find
/// weak simply come round again before the session ends.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.state,
    required this.cards,
    required this.title,
    this.scheduled = true,
  });

  final AppState state;
  final List<Flashcard> cards;
  final String title;
  final bool scheduled;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<int> _queue = [for (final c in widget.cards) c.id!];
  late final int _total = _queue.length;
  int _done = 0;
  bool _showBack = false;
  bool _busy = false;

  Flashcard? _current() {
    while (_queue.isNotEmpty && widget.state.cardById(_queue.first) == null) {
      _queue.removeAt(0);
    }
    return _queue.isEmpty ? null : widget.state.cardById(_queue.first);
  }

  Future<void> _answer(Flashcard card, int rating) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.scheduled) await widget.state.reviewCard(card, rating);
    } finally {
      if (mounted) {
        setState(() {
          final id = _queue.removeAt(0);
          if (rating == 1) {
            // Bring it back after a few other cards.
            _queue.insert(_queue.length < 4 ? _queue.length : 4, id);
          } else {
            _done++;
          }
          _showBack = false;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final card = _current();
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              if (card != null)
                IconButton(
                  tooltip: 'Edit card',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CardEditorScreen(state: widget.state, card: card),
                    ),
                  ),
                ),
            ],
          ),
          body: card == null ? _finished(context) : _cardView(context, theme, card),
        );
      },
    );
  }

  Widget _finished(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              _total == 0 ? 'Nothing to review right now.' : 'Session complete: $_done cards.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardView(BuildContext context, ThemeData theme, Flashcard card) {
    final state = widget.state;
    final path = state.topicPathFor(card.topicId);
    final labels = widget.scheduled ? state.previewLabels(card) : const <int, String>{};
    return Column(
      children: [
        LinearProgressIndicator(value: _total == 0 ? 0 : _done / _total),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  path,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${_queue.length} left', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (card.isNew)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: const Text('New'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                        ),
                      ),
                    MarkupText(card.front, style: theme.textTheme.titleLarge),
                    if (_showBack) ...[
                      const Divider(height: 32),
                      MarkupText(card.back, style: theme.textTheme.bodyLarge),
                      if (card.page != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Page ${card.page}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final f in cardFlags)
                            FilterChip(
                              label: Text(flagLabel(f)),
                              selected: card.flag == f,
                              selectedColor: flagColor(f).withOpacity(0.25),
                              onSelected: (on) => state.setCardFlag(card, on ? f : 0),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: !_showBack
                ? SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => setState(() => _showBack = true),
                      child: const Text('Show answer'),
                    ),
                  )
                : widget.scheduled
                    ? Row(
                        children: [
                          _RateButton('Again', labels[1] ?? '', Colors.red, () => _answer(card, 1)),
                          _RateButton('Hard', labels[2] ?? '', Colors.orange, () => _answer(card, 2)),
                          _RateButton('Good', labels[3] ?? '', Colors.green, () => _answer(card, 3)),
                          _RateButton('Easy', labels[4] ?? '', Colors.blue, () => _answer(card, 4)),
                        ],
                      )
                    : Row(
                        children: [
                          _RateButton('Still weak', 'see again', Colors.orange, () => _answer(card, 1)),
                          _RateButton('Know it', 'done', Colors.green, () => _answer(card, 3)),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton(this.label, this.sub, this.color, this.onTap);

  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
